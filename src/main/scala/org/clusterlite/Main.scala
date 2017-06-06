//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.io.{ByteArrayOutputStream, File}
import java.net.InetAddress
import java.util.NoSuchElementException
import java.security.MessageDigest

import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import com.fasterxml.jackson.databind.ObjectMapper
import play.api.libs.json.{JsArray, JsObject, JsValue, Json}
import com.eclipsesource.schema.{FailureExtensions, SchemaFormat, SchemaType, SchemaValidator}
import com.fasterxml.jackson.core.JsonParseException
import com.fasterxml.jackson.databind.JsonMappingException
import play.api.libs.json._


import scala.util.Try

trait AllCommandOptions {
    val isDryRun: Boolean
}

case class AnyCommandWithoutOptions(isDryRun: Boolean = false) extends AllCommandOptions {
    override def toString: String = {
        s"""
           |#    dry-run=$isDryRun
           |#""".stripMargin
    }
}

case class InstallCommandOptions(
    isDryRun: Boolean = false,
    token: String = "",
    seedsArg: String = "",
    placement: String = "default",
    publicAddress: String = "",
    dataDirectory: String = "/var/clusterlite") extends AllCommandOptions {
    override def toString: String = {
        s"""
          |#    dry-run=$isDryRun
          |#    token=$token
          |#    seeds=$seedsArg
          |#    placement=$placement
          |#    public-address=$publicAddress
          |#    data-directory=$dataDirectory
          |#""".stripMargin
    }

    lazy val seeds: Vector[String] = seedsArg.split(',').toVector.filter(i => i.nonEmpty)
}

case class ApplyCommandOptions(
    isDryRun: Boolean = false,
    config: String = "") extends AllCommandOptions {
    override def toString: String = {
        s"""
           |#    dry-run=$isDryRun
           |#    config=$config
           |#""".stripMargin
    }
}

class ErrorException(msg: String) extends Exception(msg)
class ParseException(msg: String = "") extends Exception(msg)
class EnvironmentException(msg: String) extends Exception(msg)
class PrerequisitesException(msg: String) extends Exception(msg)
class ConfigException(errors: JsArray)
    extends Exception(s"Errors:\n${Json.prettyPrint(errors)}\n" +
        "Try --help for more information.")

class Main(env: Env) {

    private val operationId = env.get(Env.ClusterliteId)
    private val dataDir: String = env.getOrElse(Env.ClusterliteData, s"/data/clusterlite/$operationId")
    private val systemConfig: Option[SystemConfiguration] = SystemConfigurationSerializer.fromJson(
        Json.parse(Utils.loadFromFile(dataDir, "clusterlite.json")).as[JsObject])
    private val weaveState: Option[WeaveState] = WeaveStateSerializer.fromJson(
        Json.parse(Utils.loadFromFile(dataDir, "weave.json")).as[JsObject])
    private val currentConfig: JsValue = Json.parse(Utils.loadFromFile(dataDir, "placements.json"))
    private val containers: JsValue = Json.parse(Utils.loadFromFile(dataDir, "docker.json"))
    private val newConfigUnpacked: Option[String] = Utils.loadFromFileIfExists(dataDir, "placements-new.json")

    private var runargs: Vector[String] = Nil.toVector

    private def run(args: Vector[String]): String = {
        runargs = args
        val command = args.headOption.getOrElse("help")
        val opts = args.drop(1)
        doCommand(command, opts)
    }

    private def doCommand(command: String, opts: Vector[String]): String = { //scalastyle:ignore

        def run[A <: AllCommandOptions](parser: scopt.OptionParser[A], d: A, action: (A) => String) = {
            parser.parse(opts, d).fold(throw new ParseException())(c => {
                val result = action(c)
                if (c.isDryRun) {
                    wrapEcho(result)
                } else {
                    result
                }
            })
        }

        command match {
            case "help" | "--help" | "-help" | "-h" =>
                val d = AnyCommandWithoutOptions()
                val parser = new scopt.OptionParser[AnyCommandWithoutOptions]("clusterlite help") {
                    help("help")
                    opt[Unit]("dry-run")
                        .action((x, c) => c.copy(isDryRun = true))
                        .maxOccurs(1)
                        .text("If set, the action will not initiate an action\n" +
                            s"but will print the script of intended actions. Default: ${d.isDryRun}")
                }
                run(parser, d, helpCommand)
            case "version" | "--version" | "-version" | "-v" =>
                val d = AnyCommandWithoutOptions()
                val parser = new scopt.OptionParser[AnyCommandWithoutOptions]("clusterlite version") {
                    help("help")
                    opt[Unit]("dry-run")
                        .action((x, c) => c.copy(isDryRun = true))
                        .maxOccurs(1)
                        .text("If set, the action will not initiate an action\n" +
                            s"but will print the script of intended actions. Default: ${d.isDryRun}")
                }
                run(parser, d, versionCommand)
            case "install" =>
                val hostInterface = if (env.get(Env.HostnameI) == "127.0.0.1") {
                    env.get(Env.Ipv4Addresses).split(" ")
                        .toVector
                        .filter(i => i != env.get(Env.HostnameI))
                        .lastOption.getOrElse(env.get(Env.HostnameI))
                } else {
                    env.get(Env.HostnameI)
                }
                val d = InstallCommandOptions()
                val parser = new scopt.OptionParser[InstallCommandOptions]("clusterlite install") {
                    help("help")
                    opt[Unit]("dry-run")
                        .action((x, c) => c.copy(isDryRun = true))
                        .maxOccurs(1)
                        .text("If set, the action will not initiate an action\n" +
                            s"but will print the script of intended actions. Default: ${d.isDryRun}")
                    opt[String]("token")
                        .required()
                        .maxOccurs(1)
                        .validate(c => if (c.length < 16) {
                            failure("token parameter should be at least 16 characters long")
                        } else {
                            success
                        })
                        .action((x, c) => c.copy(token = x))
                        .text(s"Cluster secret key. It is used for inter-node traffic encryption. Default: ${d.token}")
                    opt[String]("seeds")
                        .action((x, c) => c.copy(seedsArg = x))
                        .maxOccurs(1)
                        .text("IP addresses or hostnames of seed nodes separated by comma. " +
                            "This should be the same value for all nodes joining the cluster. " +
                            "It is NOT necessary to enumerate all nodes in the cluster as seeds. " +
                            "For high-availability it should include 3 or 5 nodes. " +
                            s"Default: ${d.seedsArg}")
                    opt[String]("data-directory")
                        .action((x, c) => c.copy(dataDirectory = x))
                        .maxOccurs(1)
                        .validate(c => if (c.isEmpty) {
                            failure("data-directory should be non empty path")
                        } else {
                            success
                        })
                        .text(s"Path to a directory where the node will persist data. Default: ${d.dataDirectory}")
                    opt[String]("placement")
                        .action((x, c) => c.copy(placement = x))
                        .maxOccurs(1)
                        .text("Role allocation for a node. It should be one of the placements " +
                            s"defined in the configuration file for apply command. Default: ${d.placement}")
                    opt[String]("public-address")
                        .action((x, c) => c.copy(publicAddress = x))
                        .maxOccurs(1)
                        .text("Public IP address of the node, if exists or requires exposure. " +
                            "This can be assigned later with help of set command. Default not assigned")
                }
                run(parser, d, installCommand)
            case "uninstall" =>
                val d = AnyCommandWithoutOptions()
                val parser = new scopt.OptionParser[AnyCommandWithoutOptions]("clusterlite uninstall") {
                    help("help")
                    opt[Unit]("dry-run")
                        .action((x, c) => c.copy(isDryRun = true))
                        .maxOccurs(1)
                        .text("If set, the action will not initiate an action\n" +
                            s"but will print the script of intended actions. Default: ${d.isDryRun}")
                }
                run(parser, d, uninstallCommand)
            case "apply" =>
                val d = ApplyCommandOptions()
                val parser = new scopt.OptionParser[ApplyCommandOptions]("clusterlite apply") {
                    help("help")
                    opt[Unit]("dry-run")
                        .action((x, c) => c.copy(isDryRun = true))
                        .maxOccurs(1)
                        .text("If set, the action will not initiate an action\n" +
                            s"but will print the script of intended actions. Default: ${d.isDryRun}")
                    opt[String]("config")
                        .required()
                        .maxOccurs(1)
                        .validate(c => {
                            newConfigUnpacked.fold(failure("config parameter points to non-existing or non-accessible file")){
                                _ => success
                            }
                        })
                        .action((x, c) => c.copy(config = x))
                        .text("Configuration to apply")
                }
                run(parser, d, applyCommand)
            case i: String =>
                helpCommand(AnyCommandWithoutOptions())
                throw new ParseException(s"Error: $i is unknown command\n" +
                    "Try --help for more information.")
        }
    }

    private def installCommand(parameters: InstallCommandOptions): String = {
        // TODO allow a client to pick alternative ip ranges for weave
        // TODO update existing peers with new peers added:
        // TODO see documentation about, investigate if it is really needed:
        // TODO For maximum robustness, you should distribute an updated /etc/sysconfig/weave file including the new peer to all existing peers.

        val weaveVersion: String = {
            val weaveVersionString = env.get(Env.WeaveVersion)
            weaveVersionString.drop("SCRIPT_VERSION=\"".length).dropRight(1)
        }
        val weaveDownloadRequired: Boolean = {
            val wv = weaveVersion
                .split('.')
                .map(i => Try(i.toLong).getOrElse(0L))
                .take(3)
                .reverse
                .zipWithIndex.map(i => i._1 << (i._2 * 8))
                .sum
            val wvRequired = "1.9.5".split('.').map(i => i.toLong)
                .reverse
                .zipWithIndex.map(i => i._1 << (i._2 * 8))
                .sum
            wv < wvRequired
        }

        val maybeSeedId = if (parameters.seedsArg.nonEmpty) {
            parameters.seeds
                .zipWithIndex
                .flatMap(a => {
                    Try(InetAddress.getAllByName(a._1).toVector)
                        .getOrElse(throw new ParseException(
                            "Error: failure to resolve all hostnames for seeds parameter\n" +
                                "Try --help for more information."))
                        .map(b=> b.getHostAddress -> a._2)
                })
                .find(a => env.get(Env.Ipv4Addresses).split(" ").contains(a._1) ||
                    env.get(Env.Ipv6Addresses).split(" ").contains(a._1))
                .map(a => a._2 + 1)
        } else {
            // when no seeds are defined, this is the first host to form a cluster
            Some(1)
        }
        val newSystemConfig = SystemConfiguration(
            parameters.token,
            parameters.seeds,
            parameters.dataDirectory,
            parameters.placement,
            parameters.publicAddress,
            maybeSeedId,
            None)
        val template = systemConfig.fold("install.sh") { current => {
            if (current != newSystemConfig) {
                throw new PrerequisitesException(
                    "Error: clusterlite is already installed with different configuration\n" +
                        "Try 'install --help' for more information.")
            }
            "install-empty.sh"
        } }
        Utils.loadFromResource(template)
            .unfold("__WEAVE_DOWNLOAD_PART__", {
                if (weaveDownloadRequired) {
                    Utils.loadFromResource("install-weave-download.sh")
                } else {
                    s"""    echo \"__LOG__ weave ($weaveVersion) detected, no download required\""""
                }
            })
            .unfold("__WEAVE_SEED_NAME__", newSystemConfig.seedId.fold(""){
                s => s"--name ::$s"
            })
            .unfold("__ETCD_LAUNCH_PART__", newSystemConfig.seedId.fold(""){
                s => {
                    Utils.loadFromResource("install-etcd-launch.sh")
                        // The “.0” and “.-1” addresses in a subnet are not used, as required by RFC 1122)
                        .unfold("__CONTAINER_IP__", s"10.32.0.$s")
                        .unfold("__ETCD_PEERS__", Seq.range(1, s).map(i => s"10.32.0.$i").mkString(" "))
                }
            })
            .unfold("__WEAVE_ALL_SEEDS__", {
                // This is the cluster signature in the unified dynamic weave cluster.
                // Clusterlite does not use automated IP address assignment feature provided by weave,
                // and the range for automated IP addresses allocation by weave is very narrow (see install.sh for the mask),
                // so this signature can be any. We pick static signature, which includes 3 ranges
                // attributed and managed by potentially 3 weave nodes, named ::1,::2,::3 accordingly.
                // If a cluster will have only 1 node deployed (initially or ever),
                // it will still work because uniform dynamic cluster does not require seeds to reach a consensus.
                "::1,::2,::3"
            })
            .unfold("__CONFIG__", "'''" + Json.stringify(newSystemConfig.toJson) + "'''")
            .unfold("__ENVIRONMENT__", env.toString)
            .unfold("__TOKEN__", parameters.token)
            .unfold("__SEEDS__", parameters.seeds.mkString(" "))
            .unfold("__PARSED_ARGUMENTS__", parameters.toString)
            .unfold("__COMMAND__", s"clusterlite ${runargs.mkString(" ")}")
            .unfold("__PUBLIC_ADDRESS__", parameters.publicAddress)
            .unfold("__VOLUME__", parameters.dataDirectory)
            .unfold("__LOG__", "[clusterlite install]")
    }

    private def uninstallCommand(parameters: AnyCommandWithoutOptions): String = {
        // TODO think about dropping loaded images and finished containers

        // as per documentation add 'weave forget' command when remote execution is possible
        // https://www.weave.works/docs/net/latest/operational-guide/uniform-fixed-cluster/
        val template = systemConfig.fold("uninstall-empty.sh") { _ => "uninstall.sh" }
        Utils.loadFromResource(template)
            .unfold("\r\n", "\n")
            .unfold("__ETCD_STOP_PART__", systemConfig.get.seedId.fold(""){
                s => Utils.loadFromResource("uninstall-etcd-stop.sh")
            })
            .unfold("__ENVIRONMENT__", env.toString)
            .unfold("__PARSED_ARGUMENTS__", parameters.toString)
            .unfold("__COMMAND__", s"clusterlite ${runargs.mkString(" ")}")
            .unfold("__VOLUME__", systemConfig.get.volume)
            .unfold("__LOG__", "[clusterlite uninstall]")
    }

    private def applyCommand(parameters: ApplyCommandOptions): String = {
        ensureInstalled()

        val newConfig = openNewConfig

        def imageExistsInLsLaOutput(image: String): Boolean = {
            val grep = Utils.loadFromFileIfExists(dataDir, "placements-dir.txt")
                .map(content => content
                    .split('\n')
                    .exists(l => l.contains(s"image-${image.replaceAll("[/:]", "-")}.tar")))
            grep.getOrElse(false)
        }

        Utils.loadFromResource("apply.sh")
            .unfold("\r\n", "\n")
            .unfold("__ENVIRONMENT__", env.toString)
            .unfold("__PARSED_ARGUMENTS__", parameters.toString)
            .unfold("__COMMAND__", s"clusterlite ${runargs.mkString(" ")}")
            .unfold("__INSTALL_SERVICES_PART__", {
                newConfig.placements.get(systemConfig.get.placement).fold({
                    s"""echo "__LOG__ ${systemConfig.get.placement} placement required by the node
                           |is not defined in the configuration"""".stripMargin
                }) { placement =>
                    assume(placement.services.nonEmpty)
                    placement.services.zipWithIndex.map(s => {
                        val serviceName = s._1._1
                        // TODO use physical container constraints
                        val servicePlacement = s._1._2
                        val serviceIndex = s._2
                        val service = newConfig.services(serviceName)
                        Utils.loadFromResource("apply-install-service.sh")
                            .unfold("__VOLUME_CREATE_PART__", if (service.stateless.getOrElse(false)) {
                                """    echo "__LOG__ __SERVICE_NAME__: stateless""""
                            } else {
                                Utils.loadFromResource("apply-volume-create.sh")
                            })
                            .unfold("__VOLUME_MOUNT_PART__", if (service.stateless.getOrElse(false)) {
                                ""
                            } else {
                                s"        --volume __VOLUME__/__CONTAINER_NAME__:/data \\\n"
                            })
                            .unfold("__DOCKER_LOAD_OR_PULL_PART__", if (imageExistsInLsLaOutput(service.image)) {
                                Utils.loadFromResource("apply-docker-load.sh")
                                    .unfold("__CONFIG_DIR__", parameters.config.split("[\\/]").dropRight(1).mkString("/"))
                                    .unfold("__IMAGE_NO_SLASH__", s"image-${service.image.replaceAll("[/:]", "-")}.tar")
                            } else {
                                Utils.loadFromResource("apply-docker-pull.sh")
                            })
                            .unfold("__CLUSTERLITE_SIGNATURE__", md5(serviceName))
                            .unfold("__SERVICE_NAME__", serviceName)
                            .unfold("__WEAVE_DNS_ADDRESS__", weaveState.get.DNS.get.Address.takeWhile(c => c != ':'))
                            .unfold("__WEAVE_DNS_DOMAIN__", weaveState.get.DNS.get.Domain)
                            .unfold("__CONTAINER_NAME__", serviceName)
                            .unfold("__CONTAINER_IP__", s"10.40.${systemConfig.get.nodeId.get}.${serviceIndex + 11}")
                            .unfold("__PUBLIC_HOST_IP__", systemConfig.get.publicIp)
                            .unfold("__ENV_DEPENDENCIES__", service.dependencies.fold(""){d =>
                                d.map(i => s"        --env ${
                                    i.toUpperCase().replace("-", "_")
                                }_SERVICE_NAME=$i.clusterlite.local \\\n")
                                .mkString("")
                            })
                            .unfold("__ENV_CUSTOM__", service.environment.fold("")(e => {
                                e.map(i => s"        --env ${i._1}=${i._2} \\\n").mkString("")
                            }))
                            .unfold("__VOLUME_CUSTOM__", service.volumes.fold("")(v => {
                                v.map(i => s"        --volume ${i._1}:${i._2} \\\n").mkString("")
                            }))
                            .unfold("__OPTIONS__", service.options.fold("")(i => s"$i \\\n        "))
                            .unfold("__IMAGE__", service.image)
                            .unfold("__COMMAND__", service.command.fold("")(i => s" \\\n        $i"))
                            .unfold("__VOLUME__", systemConfig.get.volume)
                    }).mkString("\n\n")
                }
            })
            .unfold("__LOG__", "[clusterlite apply]")
    }

    private def helpCommand(parameters: AllCommandOptions): String = {
        val used = parameters
        // TODO implement
        //        apply     Aligns current cluster state with configuration:
        //            starts newly added machines, terminates removed machines and volumes
        """Usage: clusterlite help
          |       clusterlite --help
          |       clusterlite <command> --help
          |
          |Commands:
          |       help      Prints this message
          |       version   Prints version information
          |       install   Provisions the current host and joins the cluster
          |       uninstall Leaves the cluster, uninstalls processes and data
          |       apply     Sets new configuration for services and starts them
          |""".stripMargin
    }

    private def versionCommand(parameters: AllCommandOptions): String = {
        val used = Option(parameters)
        "Webintrinsics Clusterlite, version 0.1.0"
    }

    private def ensureInstalled(): Unit = {
        systemConfig.getOrElse(throw new PrerequisitesException(
            "Error: clusterlite is not installed\n" +
            "Try 'install --help' for more information."))
        weaveState.getOrElse(throw new PrerequisitesException(
            "Error: weave network is not running, have you terminated it before?\n" +
                "Try 'weave start' to restart it again."))
        weaveState.get.DNS.getOrElse(throw new PrerequisitesException(
            "Error: weave DNS is not running, have you terminated it before?\n" +
                "Try 'weave stop && weave start' to restart it again."))
    }

    private def openNewConfig: Configuration = {
        def newConfigUntyped: JsObject = {
            val parsedConfigAsJson = try {
                val yamlReader = new ObjectMapper(new YAMLFactory())
                val obj = yamlReader.readValue(newConfigUnpacked.get, classOf[Object])
                val jsonWriter = new ObjectMapper()
                val json = jsonWriter.writeValueAsString(obj)
                Json.parse(json)
            } catch {
                case ex: Throwable =>
                    val message = ex.getMessage.replace("in 'reader', line ", "at line ")
                        .replaceAll(" at \\[Source: java.io.StringReader@.*", "")
                    throw new ParseException(
                        s"$message\n" +
                            "Error: config parameter refers to invalid YAML file\n" +
                            "Try --help for more information.")
            }
            val schema = Json.parse(Utils.loadFromResource("schema.json")).as[JsObject]
            val schemaType = Json.fromJson[SchemaType](schema).get
            SchemaValidator()
                .validate(schemaType, parsedConfigAsJson)
                .fold(invalid = errors => throw new ConfigException(errors.toJson),
                    valid = result => result.as[JsObject])
        }

        val result = ConfigurationSerializer.fromJson(newConfigUntyped)
        result.placements.foreach(p => {
            if (p._2.services.isEmpty) {
                throw new ConfigException(Json.arr(generateConfigurationErrorDetails(
                    "#/properties/placements/additionalProperties/properties/services",
                    "required",
                    s"Placement '${p._1}' does not define any reference to a service",
                    p._2.toJson,
                    s"/placements/${p._1}"
                )))
            }
            p._2.services.foreach(s => {
                if (!result.services.contains(s._1)) {
                    throw new ConfigException(Json.arr(generateConfigurationErrorDetails(
                        "#/properties/placements/additionalProperties/properties/services",
                        "reference",
                        s"Placement '${p._1}' refers to undefined service '${s._1}'",
                        p._2.toJson,
                        s"/placements/${p._1}"
                    )))
                }
            })
        })
        result.services.foreach(s => {
            s._2.dependencies.fold(())(deps => deps.foreach(d => {
                if (!result.services.contains(d)) {
                    throw new ConfigException(Json.arr(generateConfigurationErrorDetails(
                        "#/properties/services/additionalProperties/properties/dependencies",
                        "reference",
                        s"Dependency '$d' refers to undefined service",
                        s._2.toJson,
                        s"/services/${s._1}"
                    )))
                }
            }))
        })
        result
    }

    private def wrapEcho(str: String): String = {
        s"\n$str\n"
    }

    private def generateConfigurationErrorDetails(schemaPath: String, keyword: String,
        msg: String, value: JsValue, instancePath: String): JsObject = {
        Json.obj(
            "schemaPath" -> schemaPath,
            "errors" -> Json.obj(),
            "keyword" -> keyword,
            "msgs" -> Seq(msg),
            "value" -> value,
            "instancePath" -> instancePath
        )
    }

    private def md5(s: String) = MessageDigest.getInstance("MD5")
        .digest(s.getBytes).map("%02X".format(_)).mkString

    private implicit class RichString(origin: String) {
        def unfold(pattern: String, replacement: => String): String = {
            Try(replacement).fold(ex => if (origin.contains(pattern)) {
                throw ex
            } else {
                origin
            }, r => {
                origin.replace(pattern, r)
            })
        }
    }
}

object Main extends App {
    System.exit(apply(Env()))

    def apply(env: Env): Int = {
        var result = 1
        try {
            val app = new Main(env)
            System.out.print(app.run(args.toVector))
            System.out.print("\n")
            result = 0
        } catch {
            case ex: ErrorException =>
                System.out.print(s"Error: ${ex.getMessage}\n" +
                    "Try --help for more information." +
                    "[clusterlite] failure: unclassified exception\n")
            case ex: ParseException =>
                if (ex.getMessage.isEmpty) {
                    System.out.print("[clusterlite] failure: invalid argument(s)\n")
                } else {
                    System.out.print(s"${ex.getMessage}\n[clusterlite] failure: invalid arguments\n")
                }
            case ex: ConfigException =>
                System.out.print(s"${ex.getMessage}\n[clusterlite] failure: invalid configuration file\n")
            case ex: PrerequisitesException =>
                System.out.print(s"${ex.getMessage}\n[clusterlite] failure: prerequisites not satisfied\n")
            case ex: Throwable =>
                val out = new ByteArrayOutputStream
                Console.withErr(out) {
                    ex.printStackTrace()
                }
                System.out.print(s"$out\n[clusterlite] failure: internal error, " +
                    "please report to https://github.com/webintrinsics/clusterlite\n")
        }
        result
    }
}
