//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.io.{ByteArrayOutputStream, Closeable}
import java.net.InetAddress
import java.nio.file.{Files, Paths}
import java.util.concurrent.atomic.AtomicInteger

import scala.concurrent.ExecutionContext.Implicits.global
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import com.fasterxml.jackson.databind.ObjectMapper
import play.api.libs.json._
import com.eclipsesource.schema.{FailureExtensions, SchemaType, SchemaValidator}
import com.github.dockerjava.api.DockerClient
import com.github.dockerjava.api.async.ResultCallback
import com.github.dockerjava.api.exception.UnauthorizedException
import com.github.dockerjava.api.model.PullResponseItem
import com.github.dockerjava.core.command.PullImageResultCallback
import com.github.dockerjava.core.{DefaultDockerClientConfig, DockerClientBuilder}
import com.github.dockerjava.jaxrs.JerseyDockerCmdExecFactory

import scala.annotation.tailrec
import scala.collection.concurrent.TrieMap
import scala.concurrent.duration.Duration
import scala.concurrent.{Await, Future, Promise}
import scala.util.Try

trait AllCommandOptions {
    val debug: Boolean
}

case class BaseCommandOptions(debug: Boolean) extends AllCommandOptions

case class InstallCommandOptions(
    debug: Boolean,
    token: String = "",
    seedsArg: String = "",
    publicAddress: String = "",
    placement: String = "default",
    volume: String = "/var/lib/clusterlite") extends AllCommandOptions {

    lazy val seeds: Vector[String] = seedsArg.split(',').toVector.filter(i => i.nonEmpty)
}

case class LoginCommandOptions(
    debug: Boolean,
    registry: String = "registry.hub.docker.com",
    username: String = "",
    password: String = "") extends AllCommandOptions {
}

case class LogoutCommandOptions(
    debug: Boolean,
    registry: String = "registry.hub.docker.com") extends AllCommandOptions {
}

case class ApplyCommandOptions(
    debug: Boolean,
    config: String = "") extends AllCommandOptions {
}

case class ProxyInfoCommandOptions(
    debug: Boolean,
    nodes: String = "") extends AllCommandOptions {
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
        val command = args.headOption.getOrElse(
            throw new InternalErrorException("no action supplied, invoked from back door?"))
        val opts = args.drop(1)
        doCommand(command, opts)
    }

    private def doCommand(command: String, opts: Vector[String]): Int = { //scalastyle:ignore

        def run[A <: AllCommandOptions](parser: scopt.OptionParser[A], d: A, action: (A) => Int): Int = {
            val buf = new ByteArrayOutputStream()
            val parseResult = Console.withOut(buf) {
                Console.withErr(buf) {
                    parser.parse(opts, d)
                }
            }
            parseResult.fold({
                val lines = buf.toString().split('\n')
                    .map(i => if (i.startsWith("Try  for more")) {
                        "[clusterlite] Try 'clusterlite help' for more information."
                    } else {
                        s"[clusterlite] $i"
                    }).mkString("\n")
                throw new ParseException(lines)
            })(c => {
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
            case "install" =>
                val d = InstallCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[InstallCommandOptions]("clusterlite install") {
                    override def showUsageOnError: Boolean = false
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
                    opt[String]("seeds")
                        .action((x, c) => c.copy(seedsArg = x))
                        .required()
                        .maxOccurs(1)
                    opt[String]("volume")
                        .action((x, c) => c.copy(volume = x))
                        .maxOccurs(1)
                        .validate(c => if (c.isEmpty) {
                            failure("volume should be non empty path")
                        } else {
                            success
                        })
                    opt[String]("placement")
                        .action((x, c) => c.copy(placement = x))
                        .maxOccurs(1)
                    opt[String]("public-address")
                        .action((x, c) => c.copy(publicAddress = x))
                        .maxOccurs(1)
                }
                runUnit(parser, d, installCommand)
            case "uninstall" =>
                val d = BaseCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite uninstall") {
                    override def showUsageOnError: Boolean = false
                }
                runUnit(parser, d, uninstallCommand)
            case "login" =>
                val d = LoginCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[LoginCommandOptions]("clusterlite login") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("registry")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(registry = x))
                    opt[String]("username")
                        .action((x, c) => c.copy(username = x))
                        .required()
                        .maxOccurs(1)
                    opt[String]("password")
                        .action((x, c) => c.copy(password = x))
                        .required()
                        .maxOccurs(1)
                }
                runUnit(parser, d, loginCommand)
            case "logout" =>
                val d = LogoutCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[LogoutCommandOptions]("clusterlite login") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("registry")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(registry = x))
                }
                runUnit(parser, d, logoutCommand)
            case "plan" =>
                val d = ApplyCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[ApplyCommandOptions]("clusterlite plan") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("config")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(config = x))
                }
                run(parser, d, planCommand)
            case "apply" =>
                val d = ApplyCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[ApplyCommandOptions]("clusterlite apply") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("config")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(config = x))
                }
                run(parser, d, applyCommand)
            case "destroy" =>
                val d = BaseCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite destroy") {
                    override def showUsageOnError: Boolean = false
                }
                run(parser, d, destroyCommand)
            case "show" =>
                val d = BaseCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite show") {
                    override def showUsageOnError: Boolean = false
                }
                run(parser, d, showCommand)
            case "info" =>
                val d = BaseCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite info") {
                    override def showUsageOnError: Boolean = false
                }
                runUnit(parser, d, infoCommand)
            case "proxy-info" =>
                val d = ProxyInfoCommandOptions(env.isDebug)
                val parser = new scopt.OptionParser[ProxyInfoCommandOptions]("clusterlite docker") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("nodes")
                        .action((x, c) => c.copy(nodes = x))
                        .validate(c => if (c.matches("([0-9]+)([,][0-9]+)*")) {
                            success
                        } else {
                            failure("nodes should be comma separated list of numbers (ids of nodes)")
                        })
                        .maxOccurs(1)
                }
                runUnit(parser, d, proxyInfoCommand)
        }
    }

    private def installCommand(parameters: InstallCommandOptions): Unit = {
        // TODO allow a client to pick alternative ip ranges for weave
        // TODO update existing peers with new peers added:
        // TODO see documentation about, investigate if it is really needed:
        // TODO For maximum robustness, you should distribute an updated /etc/sysconfig/weave file including the new peer to all existing peers.

        val maybeSeedId = parameters.seeds
            .zipWithIndex
            .flatMap(a => {
                Try(InetAddress.getAllByName(a._1).toVector)
                    .getOrElse(throw new ParseException(
                        "[clusterlite] Error: failure to resolve all hostnames for seeds parameter\n" +
                            "[clusterlite] Try 'clusterlite help' for more information."))
                    .map(b=> b.getHostAddress -> a._2)
            })
            .find(a => env.get(Env.Ipv4Addresses).split(",").contains(a._1) ||
                env.get(Env.Ipv6Addresses).split(",").contains(a._1))
            .map(a => a._2 + 1)

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
                Utils.dashIfEmpty(parameters.volume)
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
    }

    private def loginCommand(parameters: LoginCommandOptions): Unit = {
        val node = EtcdStore.getNodes.head._2
        val creds = CredentialsConfiguration(parameters.registry,
            Some(parameters.username), Some(parameters.password))
        // if it does not throw, means login is successful
        dockerClient(node, creds)
        EtcdStore.setCredentials(creds)
        System.out.println("Login succeeded")
    }

    private def logoutCommand(parameters: LogoutCommandOptions): Unit = {
        EtcdStore.deleteCredentials(parameters.registry)
        System.out.println("Logout succeeded")
    }

    private def planCommand(parameters: ApplyCommandOptions): Int = {
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

        Utils.runProcessNonInteractive(Vector("/opt/terraform", "init", "--force-copy", "-input=false"),
            dataDir, writeConsole = parameters.debug).ensureCode()

        Utils.runProcessInteractive(s"/opt/terraform plan --out $dataDir/terraform.tfplan", dataDir)
    }

    private def applyCommand(parameters: ApplyCommandOptions): Int = {
        val nodes = EtcdStore.getNodes.values.toSeq
        val applyConfig = if (parameters.config.isEmpty) {
            EtcdStore.getApplyConfig
        } else {
            EtcdStore.setApplyConfig(openNewApplyConfig)
        }

        downloadImages(applyConfig, nodes, parameters.debug)

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes, parameters.debug)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive(Vector("/opt/terraform", "init", "--force-copy", "-input=false"),
            dataDir, writeConsole = parameters.debug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform apply", dataDir)

        // TODO release unused IP addresses
        // TODO delete unused volume folders

    }

    private def destroyCommand(parameters: BaseCommandOptions): Int = {
        val nodes = EtcdStore.getNodes
        val applyConfig = EtcdStore.getApplyConfig

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, parameters.debug)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive(Vector("/opt/terraform", "init", "--force-copy", "-input=false"),
            dataDir, writeConsole = parameters.debug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform destroy", dataDir)
    }

    private def showCommand(parameters: BaseCommandOptions): Int = {
        val nodes = EtcdStore.getNodes
        val applyConfig = EtcdStore.getApplyConfig

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, parameters.debug)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive(Vector("/opt/terraform", "init", "--force-copy", "-input=false"),
            dataDir, writeConsole = parameters.debug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform show", dataDir)
    }

    private def infoCommand(parameters: BaseCommandOptions): Unit = {
        val unused = parameters

        val nodes = EtcdStore.getNodes.values
        System.out.println("ID\tWEAVENET-ADDRESS\tHOSTNAME")
        nodes.foreach(n => {
            System.out.println(s"${n.nodeId}\t${n.weaveName}\t${n.weaveNickName}")
        })
    }

    private def proxyInfoCommand(parameters: ProxyInfoCommandOptions): Unit = {
        val nodes = EtcdStore.getNodes
        val nodeIds = if (parameters.nodes.isEmpty) {
            nodes.keys.toSeq
        } else {
            parameters.nodes.split(',').map(i => i.toInt).toSeq
        }
        val proxyAddresses = nodeIds
            .map(n => {
                val node = nodes.getOrElse(n, throw new ParseException(
                    s"[clusterlite] Error: $n is unknown node ID\n" +
                        "[clusterlite] Try 'clusterlite info' for more information."
                ))
                s"${node.nodeId}:${node.proxyAddress}"
            })
            .mkString(",")
        System.out.println(proxyAddresses) // output expected by the launcher script
    }

    private def dockerClient(n: NodeConfiguration,
        credentials: CredentialsConfiguration): DockerClient = {
        val key = s"${credentials.registry}-node-${n.nodeId}"
        dockerClientsCache.synchronized {
            dockerClientsCache.getOrElse(key, {
                val newClient = {
                    var configBuilder = DefaultDockerClientConfig.createDefaultConfigBuilder()
                        .withDockerHost(s"tcp://${n.proxyAddress}:2375")
                        .withRegistryUrl(s"https://${credentials.registry}/v1.24")
                    if (credentials.username.isDefined && credentials.password.isDefined) {
                        configBuilder = configBuilder
                            .withRegistryUsername(credentials.username.get)
                            .withRegistryPassword(credentials.password.get)
                            .withRegistryEmail("") // need this too for the library to work
                    }
                    val config = configBuilder.build()
                    val dockerCmdExecFactory = new JerseyDockerCmdExecFactory()
                        .withReadTimeout(30000)
                        .withConnectTimeout(5000)
                        .withMaxTotalConnections(100)
                        .withMaxPerRouteConnections(10)
                    val dockerClient = DockerClientBuilder.getInstance(config)
                        .withDockerCmdExecFactory(dockerCmdExecFactory)
                        .build()
                    dockerClient
                }
                dockerClientsCache = dockerClientsCache ++ Map(key -> newClient)
                if (credentials.password.isDefined && credentials.username.isDefined) {
                    try {
                        newClient.authCmd().exec()
                    }
                    catch {
                        case ex: Exception if Option(ex.getCause).getOrElse(ex)
                            .isInstanceOf[java.net.SocketTimeoutException] =>
                            throw new TimeoutException(
                                s"[clusterlite] Error: failure to connect to ${credentials.registry}\n" +
                                    s"[clusterlite] Try 'ping ${credentials.registry}'.")

                        case _: UnauthorizedException =>
                            throw new PrerequisitesException(
                                s"[clusterlite] Error: failure to login to ${credentials.registry}\n" +
                                    s"[clusterlite] Try 'clusterlite login --registry ${
                                        credentials.registry
                                    } --username <username> --password <password>'."
                            )
                    }
                }
                newClient
            })
        }
    }

    private var dockerClientsCache = Map[String, DockerClient]()

    private def downloadImages(
        applyConfig: ApplyConfiguration, nodes: Seq[NodeConfiguration], debug: Boolean): Unit = {
        // TODO implement image destruction on removed containers and destroy

        var lastStatus = ""
        val downloadProgress = TrieMap[String, (Long, Long)]()
        val completeProgress = TrieMap[String, Boolean]()
        val nodesTotal = nodes.length
        val nodesReady = new AtomicInteger()

        def getStatus = {
            val downloadStatus = {
                val current = downloadProgress.map(i => i._2._1).sum
                val total = downloadProgress.map(i => i._2._2).sum
                if (total == 0) {
                    100
                } else {
                    current * 100 / total
                }
            }
            s"[*] nodes: ${nodesReady.get}/$nodesTotal, " +
                s"layers: ${completeProgress.count(i => i._2)}/${completeProgress.count(i => true)},  " +
                s"downloaded: $downloadStatus%"
        }

        def printProgress(force: Boolean) = {
            val newStatus = getStatus
            if (newStatus != lastStatus || force) {
                lastStatus = newStatus
                if (force) {
                    System.out.println("")
                }
                System.out.println(s"\u001b[1A\u001b[K$lastStatus")
            }
        }

        def eraseProgress() = {
            System.out.println("\u001b[1A\u001b[K")
        }

        def printStatus(msg: String = "") = {
            if (msg.isEmpty) {
                printProgress(false)
            } else {
                System.out.println(s"\u001b[1A\u001b[K$msg")
                printProgress(true)
            }
        }

        printProgress(true)

        def downloadPerNode(n: NodeConfiguration, p: Placement): Vector[Future[Unit]] = {
            val perNodeImages = p.services.toVector
                .map(s => applyConfig.services(s._1).image)
                .distinct
            perNodeImages.map(image => {
                val promise = Promise[Unit]()
                val imageRef = ImageReference(image)
                val cred = EtcdStore.getCredentials(imageRef.registry)
                val client = dockerClient(n, cred)
                val callback = new PullImageResultCallback() {
                    private var lastStatus = TrieMap[String, String]()
                    private var retries = 5

                    override def onError(throwable: Throwable): Unit = {
                        super.onError(throwable)
                        throwable match {
                            case ex: Exception if Option(ex.getCause).getOrElse(ex)
                                .isInstanceOf[java.net.SocketTimeoutException] => retries -= 1
                            case _ => retries = 0
                        }
                        if (retries >= 0) {
                            printStatus(s"[${n.nodeId}] $image retrying (remaining $retries)")
                            client.pullImageCmd(image).exec(this)
                        } else {
                            printStatus(s"[${n.nodeId}] $image ${throwable.getMessage}")
                            promise.failure(throwable)
                        }
                    }
                    override def onComplete(): Unit = {
                        printStatus(s"[${n.nodeId}] $image ready")
                        promise.success(())
                    }

                    override def onNext(item: PullResponseItem): Unit = {
                        if (debug) {
                            System.err.println(item)
                        }
                        if (Option(item.getId).isDefined && !item.getStatus.startsWith("Pulling from ")) {
                            val fullId = s"${n.nodeId}${item.getId}"
                            if (lastStatus.get(fullId).fold(true)(i => i != item.getStatus)) {
                                lastStatus.update(fullId, item.getStatus)
                                printStatus(s"[${n.nodeId}] ${item.getId}: ${item.getStatus}")
                            }
                            if (item.getProgressDetail != null && item.getStatus == "Downloading") {
                                downloadProgress.update(fullId,
                                    (item.getProgressDetail.getCurrent, item.getProgressDetail.getTotal))
                            } else {
                                downloadProgress.remove(fullId)
                            }
                            if (item.getStatus == "Pull complete" || item.getStatus == "Already exists") {
                                completeProgress.update(fullId, true)
                            } else {
                                completeProgress.getOrElseUpdate(fullId, false)
                            }
                        }
                        printStatus()
                    }
                }
                client.pullImageCmd(image).exec(callback)
                promise.future
            })
        }

        val result = nodes.map(n => {
            applyConfig.placements.get(n.placement).fold(Future[Unit](())){
                p => {
                    val perNodeResult = downloadPerNode(n, p)
                    Future.sequence(perNodeResult).map(r => {
                        nodesReady.getAndIncrement()
                        printStatus(s"[${n.nodeId}] ready")
                    })
                }
            }
        })
        // TODO add error handling on various exceptions
        Await.result(Future.sequence(result), Duration("1h"))

        eraseProgress()
    }

    private def generateTerraformConfig(
        applyConfig: ApplyConfiguration, nodes: Iterable[NodeConfiguration], debug: Boolean) = {

        val nodeTemplate = Utils.loadFromResource("terraform-node.tf").trim
        val serviceTemplate = Utils.loadFromResource("terraform-service.tf").trim

        def generatePerNode(n: NodeConfiguration, p: Placement) = {
            val perNodeProvider = substituteTemplate(nodeTemplate, Map(
                "NODE_ID" -> n.nodeId.toString,
                "NODE_PROXY" -> n.proxyAddress
            ))
            val perNodeServices = p.services.map(s => {
                assume(applyConfig.services.contains(s._1))
                val service = applyConfig.services(s._1)
                //terraformServicePart(s._2, )
                substituteTemplate(serviceTemplate, Map(
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
                        }).mkString(",\n    ", ",\n    ", "")
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
                "[clusterlite] Error: config parameter points to non-existing or non-accessible file\n" +
                    "[clusterlite] Make sure file exists and has got read permissions."))
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
                            "[clusterlite] Error: config parameter refers to invalid YAML file\n" +
                            "[clusterlite] Make sure the config file has got valid YAML format.")
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
    private def substituteTemplate(text: String, templates: Map[String, String]): String = {
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
                System.err.println(s"[clusterlite] Error: ${ex.getMessage}\n" +
                    "[clusterlite] Try 'docker logs clusterlite-etcd' on seed hosts for more information.\n" +
                    "[clusterlite] failure: etcd cluster error")
                1
            case ex: EnvironmentException =>
                System.err.println(s"[clusterlite] Error: ${ex.getMessage}\n" +
                    "[clusterlite] failure: environmental error")
                1
            case ex: TimeoutException =>
                System.err.println(s"${ex.getMessage}\n" +
                    "[clusterlite] failure: timeout error")
                1
            case ex: ParseException =>
                if (ex.getMessage.isEmpty) {
                    System.err.println("[clusterlite] failure: invalid argument(s)")
                } else {
                    System.err.println(s"${ex.getMessage}\n[clusterlite] failure: invalid argument(s)")
                }
                2
            case ex: ConfigException =>
                System.err.println(s"${ex.getMessage}\n[clusterlite] failure: invalid configuration file")
                3
            case ex: PrerequisitesException =>
                System.err.println(s"${ex.getMessage}\n[clusterlite] failure: prerequisites not satisfied")
                4
            case ex: Throwable =>
                ex.printStackTrace()
                System.err.println("[clusterlite] failure: internal error, " +
                    "please report to https://github.com/webintrinsics/clusterlite")
                127
        }
    }
}
