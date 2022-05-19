const http = require("http");
const fs = require('fs')
const acmeClient = require('acme-client');
const crypto = require("crypto")
const memoize = require('memoizee')
const A_DAY = 1000*3600*24
Error.stackTraceLimit = Infinity
const Config = {
    ConsulDC: process.env["CONSUL_DC"] || "cwdc",
    VaultPath: process.env["VAULT_PATH"] || "kv/data/infrastructure/le-certs/",
    VaultListPath: process.env["VAULT_LIST_PATH"] || "kv/metadata/infrastructure/le-certs/",
    ConsulHttpChallengePath: "projects/infrastructure/le/http-01-challenges/",
    ConsulOtherDomainPath: "projects/infrastructure/le/domains",
    AcmePrivKeyPath: process.env["ACME_PEM_PATH"] || "./privkey.pem", 
    AcmeAccountUrl: process.env["ACME_ACC_URL"] || "https://acme-v02.api.letsencrypt.org/acme/acct/93137713",
    RenewalThreshold: 30, //Days
    VaultToken: process.env["VAULT_TOKEN"],
    VaultAddr: process.env["VAULT_HTTP_ADDR"] || "https://active.vault.service.consul:8200",
    MailTo: process.env["MAILTO"] || "clarkbains@scs.carleton.ca"
}

const consul = require('consul')({
    defaults: {
        token: process.env["CONSUL_HTTP_TOKEN"],
    },
    promisify: true,
    host: process.env["CONSUL_HTTP_HOST"] || "localhost"
})

const vault = require("node-vault")({
    endpoint: Config.VaultAddr,
    token: Config.VaultToken,
    requestOptions:{strictSSL:false}
});

const client = new acmeClient.Client({
    directoryUrl: acmeClient.directory.letsencrypt.production,
    accountKey: String(fs.readFileSync(Config.AcmePrivKeyPath))
})

function truthy (e) { return !!e }

function checkTags(tags, skipPrefixes = true) {
    let domains = []
    if (!Array.isArray(tags)) {
        tags = [tags]
    }
    for (let tag of tags) {
        if (res = tag.split(/`/).map(e => e.match(/^cert-for=(.*)$/)).filter(truthy).map(e => e[1])) {
            for (let match of res) {
                domains.push(...(match.split(/\s?,\s?/g)))
            }
        }
    }
    return domains
}

async function getRegisteredCatalogDomains() {
    let domains = []
    let services = await consul.catalog.service.list({dc: Config.ConsulDC})
    for (let service of Object.keys(services)) {
        domains.push(...checkTags(services[service]))
    }
    return domains
}

async function getRegisteredKVDomains() {
    let domains = []
    try {
        let value = await consul.kv.get(Config.ConsulOtherDomainPath);
        let split = value.Value.split(/\n/g)
        domains = split.filter(e=>!e.startsWith("#")).map(e=>e.replace(/\s/g, "")).filter(truthy)
    } catch (e){
        await consul.kv.set(Config.ConsulOtherDomainPath, `#Add all domains here to get LE certs for`)
    }
    return domains
}

async function needsToGenerateCert(domain){
    const currentDate = (new Date()).getTime()/A_DAY
    try {
        let current = await vault.read(Config.VaultPath + domain)
        let cert = current.data.data.cert
        const parsedCert = new crypto.X509Certificate(cert)

        validityEnd = new Date(parsedCert.validTo).getTime()/A_DAY
        if (currentDate <= (validityEnd - Config.RenewalThreshold)){
            return false
        }
    } catch (e){
    }
    return true
}

let memoizedNeedsToGenerateCert = memoize(needsToGenerateCert, { async: true, maxAge: A_DAY });

async function validateAndGenerateCert(domain, force=false){
    let b = await needsToGenerateCert(domain)
    if (!force  && !b) return
    //Only memoize false
    memoizedNeedsToGenerateCert.delete(domain);
    console.log("Attempting to get certificate for " + domain)
    const order = await client.createOrder({ identifiers: [domain].map((d) => ({ type: 'dns', value: d })) });
    const authorizations = await client.getAuthorizations(order);
    const authz = authorizations[0]
    const d = authz.identifier.value;
    let challengeCompleted = false;
    let consulPath = ""

    try {
        const challengeType = 'http-01'
        let authIdex = authz.challenges.map(e=>e.type).indexOf(challengeType)
        if (authIdex == -1) {
            throw new Error(`Unable to select challenge for ${d}, no challenge found`);
        }

        const challenge = authz.challenges[authIdex]
        if (authz.status !== 'valid'){

            const keyAuthorization = await client.getChallengeKeyAuthorization(challenge);
            consulPath = Config.ConsulHttpChallengePath + challenge.token  
            console.log(`Creating challenge for ${d} at ${consulPath}`)
            await consul.kv.set(consulPath, keyAuthorization)
            await client.verifyChallenge(authz, challenge);
            await client.completeChallenge(challenge);
            await client.waitForValidStatus(challenge);
        }
        challengeCompleted = true;

        const r = await acmeClient.forge.createCsr({
            commonName: domain
        });

        const finalized = await client.finalizeOrder(order, r[1]);
        const cert = await client.getCertificate(finalized)
        let k = r[0].toString()
        console.log("Adding cert to vault for " + d, {keyLength: k.length, certLength: cert.length}) 
        await vault.write(Config.VaultPath + d, {
            data:{
                key: k,
                cert: cert
            }
        })

        if (consulPath.startsWith(Config.ConsulHttpChallengePath)){
            await consul.kv.del(consulPath)
        }
    } catch (e){
        if (!challengeCompleted) {
            await client.deactivateAuthorization(authz);
        }
        console.log(e)
    }    
}

async function getAllDomains(){
    let domains = [
        ...(await getRegisteredCatalogDomains()),
        ...(await getRegisteredKVDomains())
    ]
    return domains
}

async function recheckAll() {
    console.log("Checking all certs")
    let domains = await getAllDomains()
    let allDomains = new Set(domains)
    for (let domain of allDomains){
        await validateAndGenerateCert(domain)
    }
}

function addWatchers(){
    let catalogWatch = consul.watch({
        method: consul.catalog.services,
        options: {dc: Config.ConsulDC},
        backoffFactor: 1000
    })
    
    let kvWatch = consul.watch({
        method: consul.kv.get,
        options: {key: Config.ConsulOtherDomainPath},
        backoffFactor: 1000
    })
    
    
    catalogWatch.on('change', async (data, res)=>{
        let s = new Set(await getRegisteredCatalogDomains())
        console.log("New changes to catalog")
        s.forEach((e) => {validateAndGenerateCert(e)})
    })
    
    
    
    kvWatch.on('change', async (data, res)=>{
        let s = new Set(await getRegisteredKVDomains())
        console.log("New changes to K/V store")
        s.forEach( (e) => {validateAndGenerateCert(e)})
    })
}



async function purge(){
    console.log("Purging old certs")
    let domainSet = new Set(await getAllDomains())
    try {
        const vaultDomains = await vault.list(Config.VaultListPath)
        let savedKeys = vaultDomains.data.keys
        for (let cert of savedKeys){
            
            if (!domainSet.has(cert)){
                //For software like Fabio, it may be nice to allow custom certs to stay
                try {
                    let certDetail = await vault.read(Config.VaultPath + cert)
                    if (Object.keys(certDetail.data.data).includes("keep")) continue;
                } catch (e){}
                try {
                    console.log(cert + " is no longer in any catalogs. Purging")
                    await vault.delete(Config.VaultPath + cert,{})
                } catch (e){}                 
            }
        }
    } catch (e){ console.log(e) }
}

//**Promises */
http.createServer(async function (req, res) {
    let path = req.url
    if (path.startsWith("/health")){
        res.write("Ok!")
        res.statusCode = 200
        res.end()
        return
    } else if (path.startsWith("/.well-known/acme-challenge/")){
        let components = path.split('/').filter(truthy)
        if (components.length == 3 && components[2].match(/^[\d\w_-]+$/)){
            let consulPath = Config.ConsulHttpChallengePath + components[2]
           // console.log("http-01 handler: Getting value from " + consulPath)
            try {
                let r = await consul.kv.get(consulPath)
                if (!r) throw new Error("Could not retrieve value for " + consulPath)
                if (answer = r.Value){
                    res.statusCode = 200
                    res.write(answer)
                    res.end()
                 //   console.log("http-01 handler: Responded with " + answer + " for " + consulPath)
                    return;
                }
            } catch (e) {
               // console.log("http-01 handler:", e )
            }
        }
       // console.log("http-01 handler: Failed to serve request for " + components[2])
    }
    res.statusCode = 400
    res.end()
}).listen(5566);

client.createAccount({
    termsOfServiceAgreed: true,
    contact: [`mailto:${Config.MailTo}`]
}).then(e=>{
    console.log("Logged into ACME Server")
    main()
})

//**Intervals */
//Not at a storage premium, so purge on a conservative basis
setInterval(purge, 10*A_DAY)
setInterval(recheckAll, A_DAY)

async function main(){
    console.log(await getAllDomains())
    await recheckAll()
    addWatchers()
    console.log("Startup Done.")
}
