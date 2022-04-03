# LE Exporter
LE exporter is a small utility I made to help manage certificates with a Hashistack deployment. If you run web, you will most likely want a reverse proxy, allowing multiple services to be load balanced, and to be available from a single IP. Traefik and Fabio both are good examples of this, and they each have good support for consul, which means that there is 0 reverse-proxy configuration needed for deploying new applications (except some labels)

## SSL
SSL is important for almost all applications, and with ACME providers like LetsEncrypt giving out free certificates, there is no real reason a site shouldn't have SSL configures


## The Issue
Traefik provides a super simple mechanism for automatically getting and using certificates from LetsEncrypt, but the community version is unable to operate in a HA (High availability) mode and still be able to handle getting and using LetsEncypt certs. If you want to run HA traefik, you would have to have it read from some shared source of certificates, that every instance can get to. Hashicorp's Vault would be perfect for this, however it is not supported as a certificate store in the community version of Traefik

Fabio is unable to get letsencypt certificates automatically, however it can integrate with vault, and retrieve them from there. Since it doesn't handle any of the state required when you go through the letsencypt cert request process, there is no state that would prevent it from being used in HA.

The issue then, is that you are left chosing between no HA, and easy certificates (traefik & LE), HA and complicated certificate distribution (traefik & synched cert stores) or HA and no easy certs (Fabio)

## The solution
By taking some features from each, and leveraging other functionality in the software stack, I created a tool that creates a 4th option. HA, and easy certs, with the downside being that it requires a second (mine) application. le-exporter connects to consul, and scrapes it for data on what urls are being used. Fabio is used as a reverse proxy, and is set to proxy a special url (.well-known/acme-challenge/*) to le-exporter. This the the url used by letsencrypt to verify ownership of a domain. By doing this, le-exporter can get a list of domains, and then get a certificate for that domain, without the other applications having to do anything. It then uploads the generated certificates into vault, where they can freely be accessed by fabio, or any other application that needs them. Since Fabio has no state (other than the information it reads from consul), it can be deployed at scale, and meanwhile le-exporter can sit in the background, watching for new domains to get certs for, getting them, uploading them, and renewing them.



## TODO
le-exporter doesn't actually watch consul yet. Currently it just polls on startup, then on a regular interval.
le-exporter does not have proper error handling for when it gets false positives on domains, so it could possibly rate limit itself with the ACME provider.
le-exporter is not very configurable at the moment, in terms of blacklisted domains for cert generation, and domains that should have certs generated regardless. I intend to add this to the consul k/v integration, so it is centralized

