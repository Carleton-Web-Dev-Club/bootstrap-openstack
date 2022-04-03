const http = require("http");
const fs = require('fs')
const acmeClient = require('acme-client');
const x509 = require('x509');
const A_DAY = 1000*3600*24
const Config = {
    ConsulDC: process.env["CONSUL_DC"] || "cwdc",
    VaultPath: process.env["VAULT_PATH"] || "kv/data/infrastructure/le-certs/",
    VaultListPath: process.env["VAULT_LIST_PATH"] || "kv/metadata/infrastructure/le-certs/",
    ConsulHttpChallengePath: "projects/infrastructure/le/http-01-challenges/",
    AcmePrivKeyPath: process.env["ACME_PEM_PATH"] || "./privkey.pem", 
    AcmeAccountUrl: process.env["ACME_ACC_URL"] || "https://acme-v02.api.letsencrypt.org/acme/acct/93137713",
    RenewalThreshold: 30, //Days
    VaultToken: process.env["VAULT_TOKEN"],
    VaultAddr: process.env["VAULT_ADDR"] || "https://active.vault.service.consul:8200"
}


const consul = require('consul')({
    defaults: {
        token: process.env["CONSUL_HTTP_TOKEN"]
    },
    promisify: true
})

const vault = require("node-vault")({
    endpoint: 'https://active.vault.service.consul:8200',
    token: Config.VaultToken
});

const client = new acmeClient.Client({
    directoryUrl: acmeClient.directory.letsencrypt.production,
    accountKey: String(fs.readFileSync(Config.AcmePrivKeyPath))
})

acmeClient.setLogger((message) => {
    //console.log(message);
});

function truthy (e) { return !!e }

function checkTags(tags, skipPrefixes = true) {
    let excludePrefixes = [
        "traefik.http",
        "traefik.enable",
        "traefik.tcp",
        ".well-known"
    ]
    let domains = []
    if (!Array.isArray(tags)) {
        tags = [tags]
    }
    for (let tag of tags) {
        if (res = tag.split(/`/).map(e => e.match(/^(?:[\w-_]*\.)*[\w-_]+\.\w+$/)).filter(truthy).map(e => e[0])) {
            for (let match of res) {
                let ok = true;
                if (!skipPrefixes){
                    for (let exclusion of excludePrefixes) {
                        if (!(ok &= !match.startsWith(exclusion))) break;
                    }
                }
                if (ok)
                    domains.push(match)
            }
        }
    }
    return domains
}

async function getRegisteredCatalogDomains() {
    let domains = []

    let dcs = await consul.catalog.datacenters()
    let services = await consul.catalog.service.list({dc: Config.ConsulDC})
    for (let service of Object.keys(services)) {
        domains.push(...checkTags(services[service]))
    }
    return domains
}

async function getRegisteredKVDomains(path) {
    let domains = []
    let routers = await consul.kv.keys({key: path})
        
    let promises = routers.filter(e => e.endsWith("/rule")).map (async e => await consul.kv.get(e))
    for (let value of (await Promise.all(promises)).map(e => e.Value)){
        domains.push(...checkTags(value))
    }
    return domains
}

async function validateAndGenerateCert(domain, force=false){
    const currentDate = (new Date()).getTime()/A_DAY
    if (!force){
        try {
            let current = await vault.read(Config.VaultPath + domain)
            let cert = current.data.data.cert
            const parsedCert = x509.parseCert(cert)
            validityEnd = new Date(parsedCert.notAfter).getTime()/A_DAY
            if (currentDate <= (validityEnd - Config.RenewalThreshold)){
                return
            }
        } catch (e){}
    }
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
async function recheckAll() {
    console.log("Checking all certs")
    let domains = [
        ...(await getRegisteredCatalogDomains()),
        ...(await getRegisteredKVDomains("traefik/http/routers"))
    ]
    let allDomains = new Set(domains)
    for (let domain of allDomains){
        await validateAndGenerateCert(domain, true)
    }
}

async function purge(){
    console.log("Purging old certs")
    let domains = [
        ...(await getRegisteredCatalogDomains()),
        ...(await getRegisteredKVDomains("traefik/http/routers"))
    ]
    let domainSet = new Set(domains)
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
    if (path.startsWith("/.well-known/acme-challenge/")){
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
    contact: [`mailto:clarkbains@gmail.com`]
}).then(e=>{
    console.log("Logged into ACME Server")
    main()
})

//**Intervals */
//Not at a storage premium, so purge on a conservative basis
setInterval(purge, 10*A_DAY)
setInterval(recheckAll, A_DAY)

async function main(){
    let domains = [
        ...(await getRegisteredCatalogDomains()),
        ...(await getRegisteredKVDomains("traefik/http/routers"))
    ]
    console.log(domains)
    await recheckAll()
    console.log("Startup Done.")
}
