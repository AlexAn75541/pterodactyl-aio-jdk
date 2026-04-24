
![license mit](https://img.shields.io/badge/license-MIT-green) 
[![build status](https://github.com/AlexAn75541/pterodactyl-aio-jdk/actions/workflows/docker-image.yml/badge.svg?branch=master)](https://github.com/AlexAn75541/pterodactyl-aio-jdk/actions/workflows/docker-image.yml)

# Pterodactyl Multi-JDK Images

A collection of Docker images for the Pterodactyl Panel, providing multiple JDK vendors in a single container. You can switch between vendors at runtime using the `JDK_VENDOR` environment variable.

## Available Images

| Java Version | Image Tag | Included JDK Vendors |
|--------------|-----------|---------------------|
| **8** | `ghcr.io/alexan75541/pterodactyl-aio-jdk:aio-8` | Temurin, Zulu, Corretto, Semeru, Liberica, Dragonwell |
| **11** | `ghcr.io/alexan75541/pterodactyl-aio-jdk:aio-11` | Temurin, Zulu, Corretto, Semeru, Liberica, Dragonwell |
| **17** | `ghcr.io/alexan75541/pterodactyl-aio-jdk:aio-17` | Temurin, **GraalVM (all 3 variants)**, Zulu, Corretto, Semeru, Liberica, Dragonwell |
| **21** | `ghcr.io/alexan75541/pterodactyl-aio-jdk:aio-21` | Temurin, **GraalVM (all 3 variants)**, Zulu, Corretto, Semeru, Liberica, Dragonwell, Shenandoah |
| **25** | `ghcr.io/alexan75541/pterodactyl-aio-jdk:aio-25` | Temurin, **GraalVM (all 3 variants)**, Zulu, Corretto, Semeru, Liberica, Dragonwell |


## Main Features

**Multiple JDK Vendors:**
- **Temurin**: Eclipse Adoptium OpenJDK, a standard and widely trusted build.
- **GraalVM**: Oracle's high-performance JDK. Available as `graalvm`, `graalvm-ce` (Community Edition), and `graalvm-native` (with Native Image).
- **Shenandoah**: An ultra-low pause time garbage collector.
- **Zulu**: Azul's certified OpenJDK build.
- **Corretto**: Amazon's production-ready OpenJDK.
- **Semeru**: IBM's OpenJ9-based runtime.
- **Liberica**: BellSoft's complete OpenJDK distribution.
- **Dragonwell**: Alibaba's optimized OpenJDK for production workloads.

> [!CAUTION]
> Not all JDK vendors are available for every Java version. Please check the "Included JDK Vendors" table for details.\
> Since almost all OpenJDK are more or less the same in term of performance, I will remove some for the sake of the images's size

**Image Optimizations:**
- Includes the full JDK (not just the JRE) with tools like `javac`, `jshell`, and `jar`(ofc `java` is always included lol). 
- Debug symbols are stripped along with documentation, samples, and demos to reduce image size.
- **jemalloc and mimalloc support**: memory allocator with built-in profiling for detecting native memory leaks(except mimalloc), both are compiled from source and included in all images but are disabled by default.

## How to Use


### Using the `JDK_VENDOR` Environment Variable

To select a JDK vendor, set the `JDK_VENDOR` environment variable in your Pterodactyl Panel.

> [!NOTE]
> If this variable is not set, the image will default to Temurin for maximum compatibility.\
> To use a specific vendor outside the panel, you can set the variable with Docker's `-e` flag:\
> `docker run -e JDK_VENDOR=zulu ghcr.io/alexan75541/pterodactyl-graalvm:aio-21`

1. Go to your Pterodactyl Admin Panel → Nests → {Your Chosen Egg}.
2. Navigate to the **Variables** tab and create a new variable.
3. Set the **Environment Variable** to `JDK_VENDOR`.
4. You can allow users to select from the following options: `temurin` (default), `graalvm`, `graalvm-ce`, `graalvm-native`, `shenandoah`, `zulu`, `corretto`, `semeru`, `liberica`, or `dragonwell`.
5. Save the variable, then restart your server for the changes to take effect.

Alternatively, you can add the following configuration to your egg's JSON file:

```
{
            "name": "JDK Vendor",
            "description": "The JDK vendor to use for running the server.\r\n\r\nOptions: `temurin`, `graalvm`, `graalvm-native`, `graalvm-ce`, `zulu`, `liberica`, `corretto`, `semeru`, `shenandoah`, `dragonwell`",
            "env_variable": "JDK_VENDOR",
            "default_value": "temurin",
            "user_viewable": true,
            "user_editable": true,
            "rules": "required|string|in:temurin,graalvm,graalvm-native,graalvm-ce,zulu,liberica,corretto,semeru,shenandoah,dragonwell",
            "field_type": "text"
}

```

Along with the list of Java version if you want:

```
"docker_images": {
        "Java 8": "ghcr.io\/alexan75541\/pterodactyl-aio-jdk:aio-8",
        "Java 11": "ghcr.io\/alexan75541\/pterodactyl-aio-jdk:aio-11",
        "Java 17": "ghcr.io\/alexan75541\/pterodactyl-aio-jdk:aio-17",
        "Java 21": "ghcr.io\/alexan75541\/pterodactyl-aio-jdk:aio-21",
        "Java 25": "ghcr.io\/alexan75541\/pterodactyl-aio-jdk:aio-25"
```

## malloc stuff (jemalloc / mimalloc)

All images include pre-compiled `jemalloc` and `mimalloc` libraries(long ahh build time), which can improve performance by optimizing memory allocation(Thanks to [Skullians's Repo](https://github.com/Skullians/native-leak-profiling)). Both are disabled by default with its associated `.so` library files and can be enabled with a startup flag.

> [!IMPORTANT]
> You can only enable one memory allocator at a time.

> [!WARNING]
> And as Skullian stated, images with `mimalloc` are experimental, proceed with cautions.

### Enabling a `*malloc`

You can enable them by using one of these flags:
```
-Djemalloc=true

       or 

-Dmimalloc=true
```
### The rest of the profiling procedure for `jemalloc` are in [this part](https://github.com/Skullians/native-leak-profiling/blob/main/README.md#usage) of his repo. Be sure to check it out if you're interested.

## License and Contributing

**MIT License - See LICENSE file**

By using Oracle's registry in this repository, I, Aretzera(AlexAn75541) or maybe users of this repository, comply to [GraalVM Free Terms and Conditions (GFTC)](https://www.oracle.com/downloads/licenses/graal-free-license.html).

Moreover, this project includes the following JDK distributions:
- **Eclipse Temurin**: GPLv2 
- **Azul Zulu**: GPLv2   
- **BellSoft Liberica**: GPLv2  
- **GraalVM Community Edition**: GPLv2
- *(And Other vendors...)*

All JDK distributions are used in accordance with their respective licenses.

### Issues and PRs welcome! This repo is maintained for personal use but shared with the community(if they care lol).

**Credits:**

- Pterodactyl Panel: https://pterodactyl.io/
- [RikoDEV's GraalVM Pterodactyl Docker Image Repo](https://github.com/RikoDEV/pterodactyl-graalvm)
- [THE OG YOLK](https://github.com/pterodactyl/yolks)
- [trenutoo's Pterodactyl Docker Image Repo](https://github.com/trenutoo/pterodactyl-images/)
- [native-leak-profiling from Skullians](https://github.com/Skullians/native-leak-profiling)
- And all JDK vendors for their amazing work so far and I hope that I won't get killed by them