//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.io.Closeable
import java.net.InetAddress
import java.nio.file.{Files, Paths}

import scala.concurrent.ExecutionContext.Implicits.global

import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import com.fasterxml.jackson.databind.ObjectMapper
import play.api.libs.json._
import com.eclipsesource.schema.{FailureExtensions, SchemaType, SchemaValidator}
import com.github.dockerjava.api.DockerClient
import com.github.dockerjava.api.async.ResultCallback
import com.github.dockerjava.api.model.PullResponseItem
import com.github.dockerjava.core.command.PullImageResultCallback
import com.github.dockerjava.core.{DefaultDockerClientConfig, DockerClientBuilder}
import com.github.dockerjava.jaxrs.JerseyDockerCmdExecFactory

import scala.annotation.tailrec
import scala.concurrent.duration.Duration
import scala.concurrent.{Await, Future, Promise}
import scala.util.Try

trait AllCommandOptions {
    val debug: Boolean
}

case class BaseCommandOptions(debug: Boolean = false) extends AllCommandOptions

case class InstallCommandOptions(
    debug: Boolean = false,
    token: String = "",
    seedsArg: String = "",
    publicAddress: String = "",
    placement: String = "default",
    dataDirectory: String = "/var/clusterlite") extends AllCommandOptions {

    lazy val seeds: Vector[String] = seedsArg.split(',').toVector.filter(i => i.nonEmpty)
}

case class ApplyCommandOptions(
    debug: Boolean = false,
    config: String = "") extends AllCommandOptions {
}

class Main(env: Env) {

    private val operationId = env.get(Env.ClusterliteId)
    private val dataDir: String = s"/data/$operationId"
    private val localNodeConfiguration: Option[LocalNodeConfiguration] = {
        val nodeId = env.get(Env.ClusterliteNodeId)
        val seedId = env.get(Env.ClusterliteSeedId)
        val volume = env.get(Env.ClusterliteVolume)
        if (nodeId.isEmpty) {
            None
        } else {
            Some(LocalNodeConfiguration(volume,
                if (seedId.isEmpty) None else Option(seedId.toInt),
                nodeId.toInt))
        }
    }

    private var runargs: Vector[String] = Nil.toVector

    private def run(args: Vector[String]): Int = {
        runargs = args
        val command = args.headOption.getOrElse("help")
        val opts = args.drop(1)
        doCommand(command, opts)
    }

    private def doCommand(command: String, opts: Vector[String]): Int = { //scalastyle:ignore

        def run[A <: AllCommandOptions](parser: scopt.OptionParser[A], d: A, action: (A) => Int): Int = {
            parser.parse(opts, d).fold(throw new ParseException())(c => {
                action(c)
            })
        }

        def runUnit[A <: AllCommandOptions](parser: scopt.OptionParser[A], d: A, action: (A) => Unit): Int = {
            run(parser, d, (a: A) => {
                action(a)
                0
            })
        }

        command match {
            case "help" | "--help" | "-help" | "-h" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite help") {
                    help("help")
                    opt[Unit]("debug")
                        .action((x, c) => c.copy(debug = true))
                        .maxOccurs(1)
                        .text(s"If set, the action will produce more diagnostics information. Default: ${d.debug}")
                }
                runUnit(parser, d, helpCommand)
            case "version" | "--version" | "-version" | "-v" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite version") {
                    help("help")
                    opt[Unit]("debug")
                        .action((x, c) => c.copy(debug = true))
                        .maxOccurs(1)
                        .text(s"If set, the action will produce more diagnostics information. Default: ${d.debug}")
                }
                runUnit(parser, d, versionCommand)
            case "install" =>
                val hostInterface = if (env.get(Env.HostnameI) == "127.0.0.1") {
                    env.get(Env.Ipv4Addresses).split(",")
                        .toVector
                        .filter(i => i != env.get(Env.HostnameI))
                        .lastOption.getOrElse(env.get(Env.HostnameI))
                } else {
                    env.get(Env.HostnameI)
                }
                val d = InstallCommandOptions()
                val parser = new scopt.OptionParser[InstallCommandOptions]("clusterlite install") {
                    help("help")
                    opt[Unit]("debug")
                        .action((x, c) => c.copy(debug = true))
                        .maxOccurs(1)
                        .text(s"If set, the action will produce more diagnostics information. Default: ${d.debug}")
                    opt[String]("token")
                        .required()
                        .maxOccurs(1)
                        .validate(c => if (c.length < 16) {
                            failure("token parameter should be at least 16 characters long")
                        } else if (c.matches("[a-zA-Z0-9]+")) {
                            success
                        } else {
                            failure("token parameter should contain only letters and digits")
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
                runUnit(parser, d, installCommand)
            case "uninstall" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite uninstall") {
                    help("help")
                    opt[Unit]("debug")
                        .action((x, c) => c.copy(debug = true))
                        .maxOccurs(1)
                        .text(s"If set, the action will produce more diagnostics information. Default: ${d.debug}")
                }
                runUnit(parser, d, uninstallCommand)
            case "plan" =>
                val d = ApplyCommandOptions()
                val parser = new scopt.OptionParser[ApplyCommandOptions]("clusterlite plan") {
                    help("help")
                    opt[Unit]("debug")
                        .action((x, c) => c.copy(debug = true))
                        .maxOccurs(1)
                        .text(s"If set, the action will produce more diagnostics information. Default: ${d.debug}")
                    opt[String]("config")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(config = x))
                        .text("New configuration to plan. Default: use the latest applied")
                }
                run(parser, d, planCommand)
            case "apply" =>
                val d = ApplyCommandOptions()
                val parser = new scopt.OptionParser[ApplyCommandOptions]("clusterlite apply") {
                    help("help")
                    opt[Unit]("debug")
                        .action((x, c) => c.copy(debug = true))
                        .maxOccurs(1)
                        .text(s"If set, the action will produce more diagnostics information. Default: ${d.debug}")
                    opt[String]("config")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(config = x))
                        .text("New configuration to apply. Default: use the latest applied")
                }
                run(parser, d, applyCommand)
            case "destroy" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite destroy") {
                    help("help")
                    opt[Unit]("debug")
                        .action((x, c) => c.copy(debug = true))
                        .maxOccurs(1)
                        .text(s"If set, the action will produce more diagnostics information. Default: ${d.debug}")
                }
                run(parser, d, destroyCommand)
            case "show" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite show") {
                    help("help")
                    opt[Unit]("debug")
                        .action((x, c) => c.copy(debug = true))
                        .maxOccurs(1)
                        .text(s"If set, the action will produce more diagnostics information. Default: ${d.debug}")
                }
                run(parser, d, showCommand)
            case i: String =>
                helpCommand(BaseCommandOptions())
                throw new ParseException(
                    s"Error: $i is unknown command\n" +
                    "Try --help for more information.")
        }
    }

    private def installCommand(parameters: InstallCommandOptions): Unit = {
        // TODO allow a client to pick alternative ip ranges for weave
        // TODO update existing peers with new peers added:
        // TODO see documentation about, investigate if it is really needed:
        // TODO For maximum robustness, you should distribute an updated /etc/sysconfig/weave file including the new peer to all existing peers.

        ensureNotInstalled()

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
                .find(a => env.get(Env.Ipv4Addresses).split(",").contains(a._1) ||
                    env.get(Env.Ipv6Addresses).split(",").contains(a._1))
                .map(a => a._2 + 1)
        } else {
            // when no seeds are defined, this is the first host to form a cluster
            Some(1)
        }

        System.out.println(
            s"${
                Utils.dashIfEmpty(maybeSeedId.fold(""){s => s.toString})
            } ${
                Utils.dashIfEmpty(parameters.seeds.mkString(","))
            } ${
                Utils.dashIfEmpty(maybeSeedId.fold(""){s => s"10.32.0.$s"})
            } ${
                Utils.dashIfEmpty(maybeSeedId.fold(""){s => Seq.range(1, s).map(i => s"10.32.0.$i").mkString(",")})
            } ${
                Utils.dashIfEmpty(parameters.dataDirectory)
            } ${
                Utils.dashIfEmpty(parameters.token)
            } ${
                Utils.dashIfEmpty(parameters.placement)
            } ${
                Utils.dashIfEmpty(parameters.publicAddress)
            }"
        )
    }

    private def uninstallCommand(parameters: BaseCommandOptions): Unit = {
        val used = parameters
        // TODO think about dropping loaded images and finished containers

        // as per documentation add 'weave forget' command when remote execution is possible
        // https://www.weave.works/docs/net/latest/operational-guide/uniform-fixed-cluster/
        ensureInstalled
    }

    private def planCommand(parameters: ApplyCommandOptions): Int = {
        ensureInstalled

        val nodes = EtcdStore.getNodes
        val applyConfig = if (parameters.config.isEmpty) {
            EtcdStore.getApplyConfig
        } else {
            openNewApplyConfig
        }

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, parameters.debug)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive("/opt/terraform init --force-copy -input=false", dataDir,
            writeConsole = parameters.debug).ensureCode()

        Utils.runProcessInteractive(s"/opt/terraform plan --out $dataDir/terraform.tfplan", dataDir)
    }

    private def applyCommand(parameters: ApplyCommandOptions): Int = {
        ensureInstalled

        val nodes = EtcdStore.getNodes
        val applyConfig = if (parameters.config.isEmpty) {
            EtcdStore.getApplyConfig
        } else {
            EtcdStore.setApplyConfig(openNewApplyConfig)
        }

        downloadImages(applyConfig, nodes.values, parameters.debug)

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, parameters.debug)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive("/opt/terraform init --force-copy -input=false", dataDir,
            writeConsole = parameters.debug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform apply", dataDir)
    }

    private def destroyCommand(parameters: BaseCommandOptions): Int = {
        ensureInstalled

        val nodes = EtcdStore.getNodes
        val applyConfig = EtcdStore.getApplyConfig

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, parameters.debug)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive("/opt/terraform init --force-copy -input=false", dataDir,
            writeConsole = parameters.debug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform destroy", dataDir)
    }

    private def showCommand(parameters: BaseCommandOptions): Int = {
        ensureInstalled

        val nodes = EtcdStore.getNodes
        val applyConfig = EtcdStore.getApplyConfig

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, parameters.debug)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive("/opt/terraform init --force-copy -input=false", dataDir,
            writeConsole = parameters.debug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform show", dataDir)
    }

    private def helpCommand(parameters: AllCommandOptions): Unit = {
        val used = parameters
        // TODO update
        //        apply     Aligns current cluster state with configuration:
        //            starts newly added machines, terminates removed machines and volumes
        System.out.println("""Usage: clusterlite help
          |       clusterlite --help
          |       clusterlite <command> --help
          |
          |Commands:
          |       help      Prints this message
          |       version   Prints version information
          |       install   Provisions the current host and joins the cluster
          |       uninstall Leaves the cluster, uninstalls processes and data
          |       plan      Tries new cluster configuration and plans provisioning of services
          |       apply     Applies new cluster configuration and provisions services
          |       destroy   Terminates and destroys all services
          |""".stripMargin)
    }

    private def versionCommand(parameters: AllCommandOptions): Unit = {
        val used = Option(parameters)
        val version = try {
            Files.readAllLines(Paths.get("/version.txt")).get(0)
        } catch {
            case ex: Throwable =>
                System.err.println(s"[clusterlite] failure read version file content: ${ex.getMessage}")
                "unknown"
        }
        System.out.println(s"Webintrinsics Clusterlite, version $version")
    }

    private def ensureNotInstalled(): Unit = {
        if (localNodeConfiguration.isDefined) {
            throw new PrerequisitesException(
                "Error: clusterlite is already installed\n" +
                    "Try 'clusterlite --help' for more information.")
        }
    }

    private def ensureInstalled: LocalNodeConfiguration = {
        localNodeConfiguration.getOrElse(throw new PrerequisitesException(
            "Error: clusterlite is not installed\n" +
            "Try 'install --help' for more information."))
    }

    private def dockerClient(n: NodeConfiguration,
        registry: String = "https://registry.hub.docker.com/v1.24",
        user: Option[String] = None, password: Option[String] = None) = {
        dockerClientsCache.getOrElse(n.nodeId, {
            val newClient = {
                var configBuilder = DefaultDockerClientConfig.createDefaultConfigBuilder()
                    .withDockerHost(s"tcp://${n.proxyAddress}:2375")
                    .withRegistryUrl(registry)
                if (user.isDefined) {
                    configBuilder = configBuilder.withRegistryUsername(user.get)
                }
                if (password.isDefined) {
                    configBuilder = configBuilder.withRegistryPassword(password.get)
                }
                val config = configBuilder.build()
                val dockerCmdExecFactory = new JerseyDockerCmdExecFactory()
                    .withReadTimeout(50000)
                    .withConnectTimeout(5000)
                    .withMaxTotalConnections(10)
                    .withMaxPerRouteConnections(10)
                val dockerClient = DockerClientBuilder.getInstance(config)
                    .withDockerCmdExecFactory(dockerCmdExecFactory)
                    .build()
                dockerClient
            }
            dockerClientsCache = dockerClientsCache ++ Map(n.nodeId -> newClient)
            newClient
        })
    }

    private var dockerClientsCache = Map[Int, DockerClient]()

    private def downloadImages(
        applyConfig: ApplyConfiguration, nodes: Iterable[NodeConfiguration], debug: Boolean): Unit = {

        // TODO implement image destruction on removed containers and destroy

        def downloadPerNode(n: NodeConfiguration, p: Placement): Vector[Future[Unit]] = {
            val perNodeImages = p.services.toVector
                .map(s => applyConfig.services(s._1).image)
                .distinct
            perNodeImages.map(image => {
                val promise = Promise[Unit]()
                val callback = new PullImageResultCallback() {
                    override def onError(throwable: Throwable): Unit = {
                        super.onError(throwable)
                        promise.failure(throwable)
                    }
                    override def onComplete(): Unit = {
                        promise.success(())
                    }

                    override def onNext(item: PullResponseItem): Unit = {
                        if (debug) {
                            System.err.println(item)
                        }
                    }
                }
                dockerClient(n).pullImageCmd(image).exec(callback)//.awaitCompletion()
                promise.future
            })
        }

        val result = nodes.flatMap(n => {
            applyConfig.placements.get(n.placement).fold(Vector[Future[Unit]]()){
                p => downloadPerNode(n, p)
            }
        }).toSeq
        Await.result(Future.sequence(result), Duration("1h"))
    }

    private def generateTerraformConfig(
        applyConfig: ApplyConfiguration, nodes: Iterable[NodeConfiguration], debug: Boolean) = {

        val nodeTemplate = Utils.loadFromResource("terraform-node.tf").trim
        val serviceTemplate = Utils.loadFromResource("terraform-service.tf").trim

        def generatePerNode(n: NodeConfiguration, p: Placement) = {
            val perNodeProvider = substituteTemplace(nodeTemplate, Map(
                "NODE_ID" -> n.nodeId.toString,
                "NODE_PROXY" -> n.proxyAddress
            ))
            val perNodeServices = p.services.map(s => {
                assume(applyConfig.services.contains(s._1))
                val service = applyConfig.services(s._1)
                //terraformServicePart(s._2, )
                substituteTemplace(serviceTemplate, Map(
                    "NODE_ID" -> n.nodeId.toString,
                    "SERVICE_NAME" -> s._1,
                    "SERVICE_IMAGE" -> service.image,
                    "CONTAINER_IP" -> EtcdStore.getOrAllocateIpAddressConfiguration(s._1, n.nodeId),
                    "VOLUME" -> n.volume,
                    "ENV_PUBLIC_HOST_IP" -> {
                        if (s._2.ports.nonEmpty && n.publicIp.nonEmpty) {
                            s",\n    ${Utils.quote(s"PUBLIC_HOST_IP=${n.publicIp}")}"
                        } else {
                            ""
                        }
                    },
                    "ENV_SERVICE_SEEDS" -> {
                        s._2.seeds.fold(""){ seedsCount =>
                            val seeds = EtcdStore.getServiceSeeds(s._1, n.nodeId, seedsCount)
                            s",\n    ${Utils.quote(s"SERVICE_SEEDS=${seeds.mkString(",")}")}"
                        }
                    },
                    "ENV_DEPENDENCIES" -> {
                        service.dependencies.fold(""){d =>
                            d.map(i =>
                                s",\n    ${Utils.quote(s"${i.toUpperCase().replace("-", "_")}_SERVICE_NAME=$i.clusterlite.local")}"
                            ).mkString("")
                        }
                    },
                    "ENV_CUSTOM" -> {
                        service.environment.fold(""){e =>
                            e.map(i =>
                                s",\n    ${Utils.quote(s"${i._1}=${Utils.backslash(i._2)}")}"
                            ).mkString("")
                        }
                    },
                    "PORTS_CUSTOM" -> {
                        s._2.ports.fold(""){p =>
                            p.map(i =>
                                s"{ external = ${i._1}, internal = ${i._2} }"
                            ).mkString("\n    ", ",\n    ", "\n  ")
                        }
                    },
                    "VOLUME_CUSTOM" -> {
                        val vol = if (service.stateless.getOrElse(false)) {
                            Map()
                        } else {
                            // TODO this directory is created automatically by docker on run
                            // TODO it needs to be removed when container is removed, probably need purge command to locate and delete unused mounts
                            // TODO directories can be removed using docker exec api via clusterlite-proxy container (it has got access to volume directory)
                            Map(s"${n.volume}/${s._1}" -> "/data")
                        }
                        val volumes = vol ++ service.volumes.getOrElse(Map())
                        volumes.map(v => {
                            val roSuffix = ":ro"
                            val mount = if (v._2.endsWith(roSuffix)) {
                                v._2.dropRight(roSuffix.length) -> true
                            } else {
                                v._2 -> false
                            }
                            s"{ host_path = ${Utils.quote(Utils.backslash(v._1))}, " +
                                s"container_path = ${Utils.quote(Utils.backslash(mount._1))}, " +
                                s"read_only = ${mount._2} }"
                        }).mkString("\n    ", ",\n    ", "\n  ")
                    },
                    "COMMAND_CUSTOM" -> {
                        service.command.fold(""){ i =>
                            s"command = [ ${i.map({
                                case a: JsString => a.toString()
                                case a: JsValue => Utils.quote(a.toString())
                            }).mkString(", ")} ]"
                        }
                    }
                ))
            }).mkString("\n\n")

            s"""
               |#${"=" * 79}
               |#
               |# Provisioning configuration for node ${n.nodeId} [${n.weaveNickName}, ${n.weaveName}]
               |#
               |$perNodeProvider
               |
               |$perNodeServices
               |
               """.stripMargin
        }

        val result = nodes.map(n => {
            applyConfig.placements.get(n.placement).fold({
                System.err.println(s"""
                       [clusterlite] '${n.placement}' placement, required by the '${n.weaveNickName}' node,
                        is not defined in the apply configuration, skipping the node
                    """.stripMargin)
                ""
            }){p => generatePerNode(n, p)}
        }).mkString("\n")
        if (debug) {
            System.err.println("Generated terraform configuration:")
            System.err.println(result)
        }
        result
    }

    private def openNewApplyConfig: ApplyConfiguration = {
        def generatePlacementConfigurationErrorDetails(schemaPath: String, keyword: String,
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

        val newConfigUnpacked = Utils.loadFromFileIfExists(dataDir, "apply-config.yaml")
            .getOrElse(throw new ParseException(
                "Error: config parameter points to non-existing or non-accessible file\n" +
                    "Try --help for more information."))
        val newConfigUntyped = {
            val parsedConfigAsJson = try {
                val yamlReader = new ObjectMapper(new YAMLFactory())
                val obj = yamlReader.readValue(newConfigUnpacked, classOf[Object])
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

        val result = ApplyConfiguration.fromJson(newConfigUntyped, newConfigUnpacked)
        result.placements.foreach(p => {
            if (p._2.services.isEmpty) {
                throw new ConfigException(Json.arr(generatePlacementConfigurationErrorDetails(
                    "#/properties/placements/additionalProperties/properties/services",
                    "required",
                    s"Placement '${p._1}' does not define any reference to a service",
                    p._2.toJson,
                    s"/placements/${p._1}"
                )))
            }
            p._2.services.foreach(s => {
                if (!result.services.contains(s._1)) {
                    throw new ConfigException(Json.arr(generatePlacementConfigurationErrorDetails(
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
                    throw new ConfigException(Json.arr(generatePlacementConfigurationErrorDetails(
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

    /**
      * source: https://stackoverflow.com/questions/6110062/simple-string-template-replacement-in-scala-and-clojure
      * Replace templates of the form {key} in the input String with values from the Map.
      *
      * @param text the String in which to do the replacements
      * @param templates a Map from Symbol (key) to value
      */
    private def substituteTemplace(text: String, templates: Map[String, String]): String = {
        val builder = new StringBuilder
        @tailrec
        def loop(text: String): String = {
            if (text.length == 0) builder.toString
            else if (text.startsWith("{")) {
                val brace = text.indexOf("}")
                if (brace < 0) builder.append(text).toString
                else {
                    val replacement = templates.get(text.substring(1, brace)).orNull
                    if (replacement != null) {
                        builder.append(replacement)
                        loop(text.substring(brace + 1))
                    } else {
                        builder.append("{")
                        loop(text.substring(1))
                    }
                }
            } else {
                val brace = text.indexOf("{")
                if (brace < 0) builder.append(text).toString
                else {
                    builder.append(text.substring(0, brace))
                    loop(text.substring(brace))
                }
            }
        }
        loop(text)
    }
}

object Main extends App {
    System.exit(apply(Env()))

    def apply(env: Env): Int = {
        try {
            val app = new Main(env)
            app.run(args.toVector)
        } catch {
            case ex: EtcdException =>
                System.err.print(s"Error: ${ex.getMessage}\n" +
                    "Try 'sudo docker logs clusterlite-etcd' on seed hosts for more information.\n" +
                    "[clusterlite] failure: etcd cluster error\n")
                1
            case ex: ParseException =>
                if (ex.getMessage.isEmpty) {
                    System.err.print("[clusterlite] failure: invalid argument(s)\n")
                } else {
                    System.err.print(s"${ex.getMessage}\n[clusterlite] failure: invalid arguments\n")
                }
                2
            case ex: ConfigException =>
                System.err.print(s"${ex.getMessage}\n[clusterlite] failure: invalid configuration file\n")
                3
            case ex: PrerequisitesException =>
                System.err.print(s"${ex.getMessage}\n[clusterlite] failure: prerequisites not satisfied\n")
                4
            case ex: Throwable =>
                ex.printStackTrace()
                System.err.print("[clusterlite] failure: internal error, " +
                    "please report to https://github.com/webintrinsics/clusterlite\n")
                127
        }
    }
}
