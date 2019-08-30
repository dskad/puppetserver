# Puppet Server in Docker <!-- omit in toc -->

## Table of Contents <!-- omit in toc -->

- [OVERVIEW](#overview)
- [QUICK START](#quick-start)
- [PORT MAPPING](#port-mapping)
- [VOLUMES AND PERSISTENT DATA](#volumes-and-persistent-data)
- [DEPLOYMENT TYPES](#deployment-types)
  - [STANDALONE](#standalone)
  - [DEDICATED CA](#dedicated-ca)
  - [COMPILE MASTERS](#compile-masters)
- [PUPPETDB INTEGRATION](#puppetdb-integration)
- [R10K USAGE](#r10k-usage)
- [CONTAINER CONFIGURATION](#container-configuration)
  - [BUILD TIME CONFIGURATION OPTIONS](#build-time-configuration-options)
  - [RUN TIME CONFIGURATION OPTIONS](#run-time-configuration-options)
    - [GENERAL](#general)
    - [PUPPET AGENT](#puppet-agent)
    - [PUPPET SERVER](#puppet-server)
    - [R10K](#r10k)

---

---

## OVERVIEW

---

## QUICK START

---

## PORT MAPPING

---

## VOLUMES AND PERSISTENT DATA

---

## DEPLOYMENT TYPES

### STANDALONE

### DEDICATED CA

### COMPILE MASTERS

---

## PUPPETDB INTEGRATION

---

## R10K USAGE

---

---

## CONTAINER CONFIGURATION

Use these environment variables when building or running a Puppet Server container to configure the puppet server.

### BUILD TIME CONFIGURATION OPTIONS

---

|             **Variable** | **Description**                     |
| -----------------------: | ----------------------------------- |
| **PUPPETSERVER_VERSION** | Version of Puppet Server to install |
|         **R10K_VERSION** | Version of R10k to install          |
|  **HIERA_EYAML_VERSION** | Version of Hirea Eyaml to install   |
|    **DUMB_INIT_VERSION** | Version of Dumb Init to install     |

### RUN TIME CONFIGURATION OPTIONS

---

#### GENERAL

|                **Variable** | Default Values | Description                                            |
| --------------------------: | -------------- | ------------------------------------------------------ |
|                   **DEBUG** | False          | Show commands and arguments when running entrypoint.sh |
| **HEALTHCHECK_ENVIRONMENT** | production     | Puppet environment to use when checking server health. |

#### PUPPET AGENT

|                  **Variable** | Default Values                      | Description                                                                        |
| ----------------------------: | ----------------------------------- | ---------------------------------------------------------------------------------- |
|                  **CERTNAME** | < container FQDN >                  | The name to use when requesting a certificate from the puppet server               |
|             **DNS_ALT_NAMES** | container hostname,  container FQDN | Comma separated list of names for which this host's certificate will also be valid |
|                    **SERVER** | puppet                              | Set the server the agent will use when connecting                                  |
|                **MASTERPORT** | 8140                                | Set the port the agent will use when connecting to the puppet server               |
|                 **CA_SERVER** | < none >                            | Hostname / IP of CA (puppet) to use when requesting certificate signature          |
|                   **CA_PORT** | < none >                            | Port number of CA (puppet) to use when requesting certificate signature            |
|         **AGENT_ENVIRONMENT** | production                          | Puppet environment to use when running the agent in the container                  |
| **RUN_PUPPET_AGENT_ON_START** | False                               | Run the agent when the container starts and apply resultant configuration          |

#### PUPPET SERVER

|                       **Variable** | Default Values | Description                                                                                          |
| ---------------------------------: | -------------- | ---------------------------------------------------------------------------------------------------- |
|                      **JAVA_ARGS** | -Xms2g -Xmx2g  | Set Puppet Server's java options                                                                     |
|                       **AUTOSIGN** | True           | Turn on basic auto signing of certificate requests                                                   |
|        **ALLOW_SUBJECT_ALT_NAMES** | True           | Allow puppet CA to sign certificates with subject alternative names                                  |
| **ALLOW_AUTHORIZATION_EXTENSIONS** | False          | Allow CA to sign certificate requests that have authorization extensions                             |
|            **ENVIRONMENT_TIMEOUT** | 0              | Set to `0` or `unlimited`. How long the Puppet master should cache data it loads from an environment |
|           **PUPPETDB_SERVER_URLS** | < none >       | Comma separated list of PuppetDB server URLs                                                         |
|             **SOFT_WRITE_FAILURE** | True           | Gracefully fail puppet runs when PuppetDB servers aren't available                                   |

#### R10K

|                 **Variable** | Default Values | Description                                                                                              |
| ---------------------------: | -------------- | -------------------------------------------------------------------------------------------------------- |
|          **R10K_SOURCE\<n>** | < none >       | Source URL for R10k and optional prefix (see documentation for examples and format)                      |
|              **CA_CERT\<n>** | < none >       | Custom root/intermediate CA certificates in PEM format to allow internally/self signed host certificates |
|             **SSH_PRIV_KEY** | < none >       | Use supplied SSH private key when connecting to git repositories via SSH urls                            |
|             **SHOW_SSH_KEY** | False          | Print the public SSH key from the automatically generated key pair                                       |
|   **GENERATED_SSH_KEY_TYPE** | ed25519        | Set the type of SSH keypair that is generated. One of ed25519, ecdsa, rsa, dsa                           |  |
| **STRICT_HOST_KEY_CHECKING** | True           | Only connect to SSH servers identified in /etc/puppetlabs/ssh/known_hosts                                |
|  **TRUST_SSH_FIRST_CONNECT** | False          | Trust remote SSH server and add signature to /etc/puppetlabs/ssh/known_hosts                             |
|          **R10K_ON_STARTUP** | False          | Perform a R10k run before starting puppet server                                                         |
