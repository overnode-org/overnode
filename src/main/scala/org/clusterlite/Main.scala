//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.io.ByteArrayOutputStream
import java.net.InetAddress
import java.nio.file.Paths
import java.util.concurrent.atomic.AtomicInteger

import scala.collection.JavaConverters.mapAsJavaMap
import scala.concurrent.ExecutionContext.Implicits.global
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import com.fasterxml.jackson.databind.ObjectMapper
import play.api.libs.json._
import com.eclipsesource.schema.{FailureExtensions, SchemaType, SchemaValidator}
import com.github.dockerjava.api.DockerClient
import com.github.dockerjava.api.model.{Frame, PullResponseItem, StreamType}
import com.github.dockerjava.core.command.{ExecStartResultCallback, PullImageResultCallback}
import com.github.dockerjava.core.{DefaultDockerClientConfig, DockerClientBuilder}
import com.github.dockerjava.jaxrs.JerseyDockerCmdExecFactory

import scala.annotation.tailrec
import scala.collection.concurrent.TrieMap
import scala.concurrent.duration.Duration
import scala.concurrent.{Await, Future, Promise}
import scala.util.Try
import org.clusterlite.Utils.ConsoleColorize

trait AllCommandOptions

case class BaseCommandOptions() extends AllCommandOptions

case class InstallCommandOptions(
    token: String = "",
    seedsArg: String = "",
    publicAddress: String = "",
    placement: String = "default",
    volume: String = "/var/lib/clusterlite") extends AllCommandOptions {

    lazy val seeds: Vector[String] = seedsArg.split(',').toVector.filter(i => i.nonEmpty)
}

case class LoginCommandOptions(
    registry: String = "registry.hub.docker.com",
    username: String = "",
    password: String = "") extends AllCommandOptions {
}

case class LogoutCommandOptions(
    registry: String = "registry.hub.docker.com") extends AllCommandOptions {
}

case class ApplyCommandOptions(
    config: String = "") extends AllCommandOptions {
}

case class UploadCommandOptions(
    source: Option[String] = None,
    target: Option[String] = None) extends AllCommandOptions {
}

case class DownloadCommandOptions(
    target: String = "") extends AllCommandOptions {
}

case class ProxyInfoCommandOptions(
    nodes: String = "") extends AllCommandOptions {
}

class Main(env: Env) {

    Utils.isDebugOn = env.isDebug

    private val operationId = env.get(Env.ClusterliteId)
    private val dataDir: String = s"/data/$operationId"
    private lazy val currentNodeId: Int = env.get(Env.ClusterliteNodeId).toInt

    private var runargs: Vector[String] = Nil.toVector

    private def run(args: Vector[String]): Int = {
        runargs = args
        val command = args.headOption.getOrElse(
            throw new InternalErrorException("no action supplied, invoked from the back door?"))
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
                val message = buf.toString().split('\n')
                    .filter(i => !i.startsWith("Try  for more"))
                    .mkString("\n")
                throw new ParseException(message, HelpTryErrorMessage())
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
                val d = InstallCommandOptions()
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
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite uninstall") {
                    override def showUsageOnError: Boolean = false
                }
                runUnit(parser, d, uninstallCommand)
            case "login" =>
                val d = LoginCommandOptions()
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
                val d = LogoutCommandOptions()
                val parser = new scopt.OptionParser[LogoutCommandOptions]("clusterlite login") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("registry")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(registry = x))
                }
                runUnit(parser, d, logoutCommand)
            case "upload" =>
                val d = UploadCommandOptions()
                val parser = new scopt.OptionParser[UploadCommandOptions]("clusterlite upload") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("source")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(source = Some(x)))
                    opt[String]("target")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(target = Some(x)))
                }
                runUnit(parser, d, uploadCommand)
            case "download" =>
                val d = DownloadCommandOptions()
                val parser = new scopt.OptionParser[DownloadCommandOptions]("clusterlite download") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("target")
                        .maxOccurs(1)
                        .required()
                        .action((x, c) => c.copy(target = x))
                }
                runUnit(parser, d, downloadCommand)
            case "plan" =>
                val d = ApplyCommandOptions()
                val parser = new scopt.OptionParser[ApplyCommandOptions]("clusterlite plan") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("config")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(config = x))
                }
                run(parser, d, planCommand)
            case "apply" =>
                val d = ApplyCommandOptions()
                val parser = new scopt.OptionParser[ApplyCommandOptions]("clusterlite apply") {
                    override def showUsageOnError: Boolean = false
                    opt[String]("config")
                        .maxOccurs(1)
                        .action((x, c) => c.copy(config = x))
                }
                run(parser, d, applyCommand)
            case "destroy" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite destroy") {
                    override def showUsageOnError: Boolean = false
                }
                run(parser, d, destroyCommand)
            case "services" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite services") {
                    override def showUsageOnError: Boolean = false
                }
                run(parser, d, servicesCommand)
            case "nodes" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite nodes") {
                    override def showUsageOnError: Boolean = false
                }
                runUnit(parser, d, nodesCommand)
            case "users" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite users") {
                    override def showUsageOnError: Boolean = false
                }
                runUnit(parser, d, usersCommand)
            case "files" =>
                val d = BaseCommandOptions()
                val parser = new scopt.OptionParser[BaseCommandOptions]("clusterlite files") {
                    override def showUsageOnError: Boolean = false
                }
                runUnit(parser, d, filesCommand)
            case "proxy-info" =>
                val d = ProxyInfoCommandOptions()
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
                        "failure to resolve all hostnames for seeds parameter",
                        HelpTryErrorMessage()))
                    .map(b=> b.getHostAddress -> a._2)
            })
            .find(a => env.get(Env.Ipv4Addresses).split(",").contains(a._1) ||
                env.get(Env.Ipv6Addresses).split(",").contains(a._1))
            .map(a => a._2 + 1)

        Utils.println(
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
        val node = EtcdStore.getNode(currentNodeId)
        val creds = CredentialsConfiguration(parameters.registry, Some(parameters.username), Some(parameters.password))
        val client = dockerClient(node, creds)
        try {
            client.authCmd().exec()
        } catch {
            case ex: Throwable => throw mapDockerExecException(ex, node, creds)
        }
        EtcdStore.setCredentials(creds)
        Utils.println(s"[${parameters.registry}] Credentials saved")
    }

    private def logoutCommand(parameters: LogoutCommandOptions): Unit = {
        if (EtcdStore.deleteCredentials(parameters.registry)) {
            Utils.println(s"[${parameters.registry}] Credentials deleted")
        } else {
            throw new ParseException(
                s"${parameters.registry} is unknown registry",
                TryErrorMessage("clusterlite users", "to list available registries and users"))
        }
    }

    private def uploadCommand(parameters: UploadCommandOptions): Unit = {
        if (parameters.source.isDefined) {
            val source = parameters.source.get
            val sourceFileName = Paths.get(source).toFile.getName
            val target = parameters.target.getOrElse(sourceFileName)

            val newFile = Utils.loadFromFileIfExists(dataDir, sourceFileName)
                .getOrElse(throw new ParseException(
                    "source parameter points to non-existing or non-accessible file",
                    TryErrorMessage(s"touch ${parameters.source} && chmod u+r ${parameters.source}",
                        "to make sure file exists and has got read permissions")))
            EtcdStore.setFile(target, newFile)

            if (isFileUsed(target)) {
                Utils.info("Run 'clusterlite apply' to provision the file to the services")
            }
            Utils.println(s"[$target] File uploaded")
        } else {
            if (parameters.target.isEmpty) {
                throw new ParseException(
                    "source or target or both arguments are required",
                    HelpTryErrorMessage())
            }
            val target = parameters.target.get
            if (isFileUsed(target)) {
                throw new PrerequisitesException(
                    s"$target is used in apply configuration, so can not be deleted",
                    TryErrorMessage("clusterlite apply --config /new/config",
                        "to remove dependency to the file"))
            }
            if (EtcdStore.deleteFile(target)) {
                Utils.println(s"[$target] File deleted")
            } else {
                throw new ParseException(
                    s"$target is unknown file",
                    MultiTryErrorMessage(Vector(
                        TryErrorMessage("clusterlite files", "to list available files"),
                        TryErrorMessage(s"clusterlite upload --source </path/to/file> --target $target",
                            "to upload new file")
                    )))
            }
        }
    }

    private def downloadCommand(parameters: DownloadCommandOptions): Unit = {
        val target = parameters.target
        val content = EtcdStore.getFile(target).getOrElse(
            throw new ParseException(
                s"$target is unknown file",
                MultiTryErrorMessage(Vector(
                    TryErrorMessage("clusterlite files", "to list available files"),
                    TryErrorMessage(s"clusterlite upload --source </path/to/file> --target $target",
                        "to upload new file")
                )))
        )
        Utils.print(content) // no new line, print the file as is
    }

    private def filesCommand(parameters: BaseCommandOptions): Unit = {
        val unused = parameters
        val applyConfiguration = EtcdStore.getApplyConfig
        val nodes = EtcdStore.getNodes.values.toVector
        EtcdStore.getFiles.foreach(f => {
            val status = if (isFileUsed(f._1, applyConfiguration, nodes)) {
                "used".green
            } else {
                "unused".yellow
            }
            Utils.println(s"[${f._1}]\t${f._2}\t$status")
        })
    }

    private def planCommand(parameters: ApplyCommandOptions): Int = {
        // TODO restart containers where uploaded files are changes

        val nodes = EtcdStore.getNodes
        val applyConfig = if (parameters.config.isEmpty) {
            EtcdStore.getApplyConfig
        } else {
            openNewApplyConfig(parameters.config)
        }

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, EtcdStore.getFiles)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive(Vector("/opt/terraform", "init", "--force-copy", "-input=false"),
            dataDir, writeConsole = env.isDebug).ensureCode()

        Utils.runProcessInteractive(s"/opt/terraform plan --out $dataDir/terraform.tfplan", dataDir)
    }

    private def applyCommand(parameters: ApplyCommandOptions): Int = {
        // TODO restart containers where uploaded files are changes

        val nodes = EtcdStore.getNodes.values.toVector
        val applyConfig = if (parameters.config.isEmpty) {
            EtcdStore.getApplyConfig
        } else {
            EtcdStore.setApplyConfig(openNewApplyConfig(parameters.config))
        }

        val availableEditions = EtcdStore.getFiles
        downloadFiles(applyConfig, nodes, availableEditions)

        downloadImages(applyConfig, nodes)

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes, availableEditions)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive(Vector("/opt/terraform", "init", "--force-copy", "-input=false"),
            dataDir, writeConsole = env.isDebug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform apply", dataDir)

        // TODO release unused IP addresses
        // TODO delete unused volume folders

    }

    private def destroyCommand(parameters: BaseCommandOptions): Int = {
        val unused = parameters

        val nodes = EtcdStore.getNodes
        val applyConfig = EtcdStore.getApplyConfig

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, EtcdStore.getFiles)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive(Vector("/opt/terraform", "init", "--force-copy", "-input=false"),
            dataDir, writeConsole = env.isDebug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform destroy", dataDir)
    }

    private def servicesCommand(parameters: BaseCommandOptions): Int = {
        val unused = parameters

        val nodes = EtcdStore.getNodes
        val applyConfig = EtcdStore.getApplyConfig

        val backendTemplate = Utils.loadFromResource("terraform-backend.tf").trim
        Utils.writeToFile(backendTemplate, s"$dataDir/backend.tf")

        val terraformConfig = generateTerraformConfig(applyConfig, nodes.values, EtcdStore.getFiles)
        Utils.writeToFile(terraformConfig, s"$dataDir/terraform.tf")

        Utils.runProcessNonInteractive(Vector("/opt/terraform", "init", "--force-copy", "-input=false"),
            dataDir, writeConsole = env.isDebug).ensureCode()

        Utils.runProcessInteractive("/opt/terraform show", dataDir)
    }

    private def nodesCommand(parameters: BaseCommandOptions): Unit = {
        val unused = parameters

        val nodes = EtcdStore.getNodes.values
        val creds = CredentialsConfiguration()
        nodes.foreach(n => {
            val status = try {
                dockerClient(n, creds).listContainersCmd().exec()
                "reachable".green
            } catch {
                case origin: Throwable =>
                    mapDockerExecException(origin, n, creds) match {
                        case _: ProxyException => "unreachable".red
                        case ex: Throwable => throw ex
                    }
            }
            Utils.println(s"[${n.nodeId}]\t${n.weaveName}\t${n.weaveNickName}\t$status")
        })
    }

    private def usersCommand(parameters: BaseCommandOptions): Unit = {
        val unused = parameters

        val node = EtcdStore.getNode(currentNodeId)
        EtcdStore.getCredentials.foreach(c => {
            val status = try {
                val client = dockerClient(node, c)
                try {
                    client.authCmd().exec()
                } catch {
                    case ex: Throwable => throw mapDockerExecException(ex, node, c)
                }
                "valid".green
            } catch {
                case _: AuthenticationException => "invalid".red
                case ex: Throwable => throw ex
            }
            Utils.println(s"[${c.registry}]\t${c.username.get}\t${c.password.getOrElse("").replaceAll(".", "*")}\t$status")
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
                    s"$n is unknown node ID",
                    TryErrorMessage("clusterlite nodes", "to list available nodes")
                ))
                s"${node.nodeId}:${node.proxyAddress}"
            })
            .mkString(",")
        Utils.println(proxyAddresses) // output expected by the launcher script
    }

    private def dockerClient(n: NodeConfiguration, credentials: CredentialsConfiguration): DockerClient = {
        val key = s"${credentials.registry}-node-${n.nodeId}-cred-${credentials.username.getOrElse("")}"
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
                newClient
            })
        }
    }

    private var dockerClientsCache = Map[String, DockerClient]()

    private def downloadFiles(
        applyConfig: ApplyConfiguration, nodes: Vector[NodeConfiguration], editions: Map[String, Long]): Unit = {

        var lastStatus = ""
        val nodesTotal = nodes.length
        val nodesReady = new AtomicInteger()
        val filesTotal = new AtomicInteger()
        val filesReady = new AtomicInteger()

        val lock = new Object()

        def getStatus = {
            s"[*] nodes: ${nodesReady.get}/$nodesTotal, files: ${filesReady.get}/${filesTotal.get}".yellow
        }
        def printProgress(force: Boolean) = {
            val newStatus = getStatus
            if (newStatus != lastStatus || force) {
                lastStatus = newStatus
                if (force) {
                    Utils.println("")
                }
                Utils.println(s"\u001b[1A\u001b[K$lastStatus")
            }
        }
        def printStatus(msg: String = "") = lock.synchronized {
            if (msg.isEmpty) {
                printProgress(false)
            } else {
                Utils.println(s"\u001b[1A\u001b[K$msg")
                printProgress(true)
            }
        }

        printProgress(true)

        val creds = CredentialsConfiguration()
        val futures = nodes.map(n => {
            val client = dockerClient(n, creds)
            applyConfig.placements.get(n.placement).fold(Future.successful(n.nodeId)){
                p => {
                    val perNodeFilesNames = p.services.toVector
                        .flatMap(s => applyConfig.services(s._1).files.getOrElse(Map()).keys)
                    filesTotal.addAndGet(perNodeFilesNames.length)
                    printStatus()

                    val command = Vector("/run-proxy-fetch.sh") ++
                        perNodeFilesNames.flatMap(i => Vector(i, editions(i).toString))
                    val execCreateResult = try {
                        client.execCreateCmd("clusterlite-proxy")
                            .withAttachStderr(true)
                            .withAttachStdin(false)
                            .withAttachStdout(true)
                            .withCmd(command: _*)
                            .exec()
                    } catch {
                        case ex: Throwable => throw mapDockerExecException(ex, n, creds)
                    }
                    Utils.debug(execCreateResult.toString)
                    val promise = Promise[Int]()
                    val callback = new ExecStartResultCallback() {
                        private val buffer = new StringBuilder()
                        override def onError(throwable: Throwable): Unit = {
                            val output = buffer.toString()
                            printStatus(output.split('\n').map(i => s"[${n.nodeId}] $i").mkString("\n").red)
                            val msg = Try((Json.parse(throwable.getMessage) \ "message").as[String])
                                .getOrElse(throwable.getMessage)
                            printStatus(s"[${n.nodeId}] $msg".red)
                            promise.failure(mapDockerExecException(throwable, n, creds))
                        }
                        override def onComplete(): Unit = {
                            val output = buffer.toString()
                            if (output.contains("[clusterlite proxy-fetch] success: action completed")) {
                                promise.success(n.nodeId)
                            } else if (output.contains(
                                "[clusterlite proxy-fetch] failure: action aborted: newer file edition")) {
                                printStatus(output.split('\n').map(i => s"[${n.nodeId}] $i").mkString("\n").yellow)
                                promise.failure(new PrerequisitesException(
                                    "newer file has been uploaded since the last planning of the change",
                                    TryErrorMessage("clusterlite apply", "to redo the action")
                                ))
                            } else {
                                printStatus(output.split('\n').map(i => s"[${n.nodeId}] $i").mkString("\n").red)
                                promise.failure(new InternalErrorException("unexpected proxy-fetch output"))
                            }
                        }
                        override def onNext(frame: Frame): Unit = {
                            Utils.debug(frame.toString)
                            val output = new String(frame.getPayload)
                            if (frame.getStreamType == StreamType.STDOUT) {
                                output.split('\n').foreach(l => {
                                    val expectedProgressText = "[clusterlite proxy-fetch] done "
                                    if (l.startsWith(expectedProgressText)) {
                                        val file = l.substring(expectedProgressText.length)
                                        filesReady.incrementAndGet()
                                        printStatus(s"[${n.nodeId}] [$file] ready".green)
                                    }
                                })
                                buffer.append(output)
                            } else {
                                printStatus(output.split('\n').map(i => s"[${n.nodeId}] $i").mkString("\n").red)
                            }
                        }
                    }
                    client.execStartCmd(execCreateResult.getId).exec(callback)
                    promise.future
                }
            }
        })
        val tracedFutures = futures.map(f => f.map(i => {
            nodesReady.incrementAndGet()
            printStatus(s"[${i}] all files ready".green)
        }))
        Await.result(Future.sequence(tracedFutures), Duration("1h"))
        printStatus("[*] all files ready".green)
    }

    private def downloadImages(
        applyConfig: ApplyConfiguration, nodes: Vector[NodeConfiguration]): Unit = {
        // TODO implement image destruction on removed containers and destroy

        var lastStatus = ""
        val downloadProgress = TrieMap[String, (Long, Long)]()
        val completeProgress = TrieMap[String, Boolean]()
        val nodesTotal = nodes.length
        val nodesReady = new AtomicInteger()
        val imagesTotal = new AtomicInteger()
        val imagesReady = new AtomicInteger()

        val lock = new Object()

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
            (s"[*] nodes: ${nodesReady.get}/$nodesTotal, " +
                s"images: ${imagesReady.get}/${imagesTotal.get}, " +
                s"layers: ${completeProgress.count(i => i._2)}/${completeProgress.count(i => true)}, " +
                s"downloaded: $downloadStatus%").yellow
        }
        def printProgress(force: Boolean) = {
            val newStatus = getStatus
            if (newStatus != lastStatus || force) {
                lastStatus = newStatus
                if (force) {
                    Utils.println("")
                }
                Utils.println(s"\u001b[1A\u001b[K$lastStatus")
            }
        }
        def printStatus(msg: String = "") = lock.synchronized {
            if (msg.isEmpty) {
                printProgress(false)
            } else {
                Utils.println(s"\u001b[1A\u001b[K$msg")
                printProgress(true)
            }
        }

        def downloadImagePerNode(n: NodeConfiguration, image: String): Future[Unit] = {
            imagesTotal.incrementAndGet()
            printStatus()

            val promise = Promise[Unit]()
            val imageRef = ImageReference(image)
            val cred = EtcdStore.getCredentials(imageRef.registry)
            val client = dockerClient(n, cred)
            def callback(attempts: Int): PullImageResultCallback = new PullImageResultCallback() {
                private val lastStatus = TrieMap[String, String]()
                private var retries = attempts
                private var afterError = false

                override def onError(throwable: Throwable): Unit = {
                    afterError = true

                    val msg = Try((Json.parse(throwable.getMessage) \ "message").as[String])
                        .getOrElse(throwable.getMessage)
                    printStatus(s"[${n.nodeId}] [$image] $msg".red)

                    def abort(ex: Throwable) = {
                        Utils.debug(s"[${n.nodeId}] [$image] aborting due to: ${ex.getMessage}")
                        promise.failure(ex)
                        close()
                    }
                    def retry(ex: BaseException) = {
                        retries -= 1
                        if (retries >= 0) {
                            printStatus(s"[${n.nodeId}] [$image] retrying (remaining retries $retries)".red)
                            client.pullImageCmd(image).exec(callback(retries))
                        } else {
                            printStatus(s"[${n.nodeId}] [$image] no remaining retries".red)
                            abort(ex)
                        }
                    }

                    mapDockerExecException(throwable, n, cred) match {
                        case ex: RegistryException => retry(ex)
                        case ex: ProxyException => retry(ex)
                        case ex: Throwable => abort(ex)
                    }
                }

                override def onComplete(): Unit = {
                    if (!afterError && !promise.isCompleted) {
                        imagesReady.incrementAndGet()
                        printStatus(s"[${n.nodeId}] [$image] ready".green)
                        promise.success(())
                    }
                }

                override def onNext(item: PullResponseItem): Unit = {
                    Utils.debug(item.toString)
                    afterError = false
                    if (Option(item.getId).isDefined && !item.getStatus.startsWith("Pulling from ")) {
                        val fullId = s"${n.nodeId}${item.getId}"
                        if (lastStatus.get(fullId).fold(true)(i => i != item.getStatus)) {
                            lastStatus.update(fullId, item.getStatus)
                            printStatus(s"[${n.nodeId}] [$image] ${item.getId}: ${item.getStatus}")
                        }
                        if (item.getProgressDetail != null && item.getStatus == "Downloading") {
                            downloadProgress.update(fullId,
                                (item.getProgressDetail.getCurrent, item.getProgressDetail.getTotal))
                        } else if (downloadProgress.contains(fullId)) {
                            // report full completeness for the layer
                            downloadProgress.update(fullId,
                                downloadProgress(fullId)._2 -> downloadProgress(fullId)._2)
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
            client.pullImageCmd(image).exec(callback(5)) // TODO make number of retries configurable
            promise.future
        }

        printProgress(true)

        val result = nodes.flatMap(n => {
            applyConfig.placements.get(n.placement).fold(Vector[Future[Unit]]()){
                p => {
                    val perNodeImages = p.services.toVector
                        .map(s => applyConfig.services(s._1).image)
                        .distinct
                    val perNodeResult = perNodeImages
                        .map(image => downloadImagePerNode(n, image))
                    val perNodeStatus = Future.sequence(perNodeResult).map(r => {
                        nodesReady.getAndIncrement()
                        printStatus(s"[${n.nodeId}] all images ready".green)
                    }).recover({
                        case _: Throwable => () // ignore this error, as it is only necessary for correct output order
                    })
                    perNodeResult ++ Vector(perNodeStatus) // add this to synchronize overall status print
                }
            }
        })

        var errors = Vector[BaseException]()
        result.foreach(f => {
            try {
                Await.result(f, Duration("1d"))
            } catch {
                case ex: BaseException => errors = errors ++ Vector(ex)
                case ex: Throwable => throw new InternalErrorException("unexpected exception", ex)
            }
        })
        if (errors.nonEmpty) {
            throw new AggregatedException(errors)
        } else {
            printStatus("[*] all images ready".green)
        }
    }

    private def spawnServices(
        applyConfig: ApplyConfiguration, nodes: Vector[NodeConfiguration]): Unit = {

        var lastStatus = ""
        val nodesTotal = nodes.length
        val nodesReady = new AtomicInteger()
        val servicesTotal = new AtomicInteger()
        val servicesReady = new AtomicInteger()

        val lock = new Object()

        def getStatus = {
            (s"[*] nodes: ${nodesReady.get}/$nodesTotal, " +
                s"containers: ${servicesReady.get}/${servicesTotal.get}").yellow
        }
        def printProgress(force: Boolean) = {
            val newStatus = getStatus
            if (newStatus != lastStatus || force) {
                lastStatus = newStatus
                if (force) {
                    Utils.println("")
                }
                Utils.println(s"\u001b[1A\u001b[K$lastStatus")
            }
        }
        def printStatus(msg: String = "") = lock.synchronized {
            if (msg.isEmpty) {
                printProgress(false)
            } else {
                Utils.println(s"\u001b[1A\u001b[K$msg")
                printProgress(true)
            }
        }

        def spawnServicePerNode(n: NodeConfiguration, serviceName: String, service: Service): Future[Unit] = {
            servicesTotal.incrementAndGet()
            printStatus()

            // TODO parallel this code?
            val promise = Promise[Unit]()
            val imageRef = ImageReference(service.image)
            val cred = EtcdStore.getCredentials(imageRef.registry)
            val client = dockerClient(n, cred)

            try {
                val createContainerCmd = client.createContainerCmd(service.image)
                    .withAttachStderr(false)
                    .withAttachStdin(false)
                    .withAttachStdout(false)
                    .withLabels(mapAsJavaMap(Map("clusterlite" -> env.version)))
                    .withName(serviceName)
                val createContainerResponse = createContainerCmd.exec()
                client.startContainerCmd(createContainerResponse.getId).exec()
                promise.success(())

                val containersList = client.listContainersCmd()
                    .withShowAll(true)
                    .withLabelFilter("clusterlite")
                    .exec()
                val containerId = containersList.get(0).getId
                val inspectResult = client.inspectContainerCmd(containerId).exec()
                //inspectResult.getConfig
            } catch {
                case ex: Throwable => promise.failure(mapDockerExecException(ex, n, cred))
            }
            promise.future
        }

        printProgress(true)

        val result = nodes.flatMap(n => {
            applyConfig.placements.get(n.placement).fold(Vector[Future[Unit]]()){
                p => {
                    val perNodeServices = p.services.toVector
                        .map(s => s._1 -> applyConfig.services(s._1))
                    val perNodeResult = perNodeServices
                        .map(service => spawnServicePerNode(n, service._1, service._2)
                            .map(f => {
                                servicesReady.incrementAndGet()
                                printStatus()
                                f
                            }))
                    val perNodeStatus = Future.sequence(perNodeResult).map(r => {
                        nodesReady.getAndIncrement()
                        printStatus(s"[${n.nodeId}] all services ready".green)
                    }).recover({
                        case _: Throwable => () // ignore this error, as it is only necessary for correct output order
                    })
                    perNodeResult ++ Vector(perNodeStatus) // add this to synchronize overall status print
                }
            }
        })

        var errors = Vector[BaseException]()
        result.foreach(f => {
            try {
                Await.result(f, Duration("1h"))
            } catch {
                case ex: BaseException => errors = errors ++ Vector(ex)
                case ex: Throwable => throw new InternalErrorException("unexpected exception", ex)
            }
        })
        if (errors.nonEmpty) {
            throw new AggregatedException(errors)
        } else {
            printStatus("[*] all services ready".green)
        }
    }

    private def mapDockerExecException(origin: Throwable,
        n: NodeConfiguration, credentials: CredentialsConfiguration): BaseException = {
        Utils.debug(s"[${n.nodeId}] origin docker exec exception: ${origin.getMessage}")
        Utils.debug(origin)
        val result = origin match {
            // docker proxy not reachable cases
            case ex: org.apache.http.conn.HttpHostConnectException =>
                new ProxyException(n.nodeId, n.weaveNickName, ex)
            case ex: java.net.NoRouteToHostException =>
                new ProxyException(n.nodeId, n.weaveNickName, ex)
            case ex: javax.ws.rs.ProcessingException
                if Option(ex.getCause).getOrElse(ex).isInstanceOf[org.apache.http.conn.HttpHostConnectException] ||
                   Option(ex.getCause).getOrElse(ex).isInstanceOf[java.net.NoRouteToHostException] =>
                new ProxyException(n.nodeId, n.weaveNickName, ex)

            // docker registry not reachable cases
            case ex: java.net.SocketTimeoutException =>
                new RegistryException(credentials.registry, ex.getMessage, ex)
            case ex: javax.ws.rs.ProcessingException
                if Option(ex.getCause).getOrElse(ex).isInstanceOf[java.net.SocketTimeoutException] =>
                new RegistryException(credentials.registry, ex.getMessage, ex)

            // authentication problem case
            case ex: com.github.dockerjava.api.exception.UnauthorizedException =>
                new AuthenticationException(credentials.registry, credentials.username.get, credentials.password.get, ex)

            // any docker exception trapped...
            case ex: com.github.dockerjava.api.exception.DockerException =>
                val msg = Try((Json.parse(ex.getMessage) \ "message").as[String]).getOrElse(ex.getMessage)
                if (msg.endsWith("i/o timeout") ||
                    msg.endsWith("connection refused") ||
                    msg.contains("exceeded while awaiting headers") ||
                    msg.endsWith("TLS handshake timeout")) {
                    // .. and it tells docker registry is not reachable
                    new RegistryException(credentials.registry, msg, ex)
                } else if (msg.contains("does not exist or no pull access")) {
                    // .. or image does not exists
                    val tryMsg = if (credentials.username.isEmpty) {
                        TryErrorMessage(
                            s"clusterlite login --registry ${credentials.registry} --username <user> --password <pass>",
                            "to save access credentials to a private repository")
                    } else {
                        TryErrorMessage(
                            "clusterlite users",
                            s"to check if ${credentials.username.get} user credentials are still valid for ${credentials.registry} registry")
                    }
                    new AnyDockerException(msg, tryMsg, ex)
                } else {
                    // .. or anything else
                    new AnyDockerException(msg, NoTryErrorMessage(), ex)
                }

            // if nothing above is matched, it is an internal error
            case ex: Throwable => new InternalErrorException("unexpected docker exception", ex)
        }
        Utils.debug(s"[${n.nodeId}] mapped docker exec exception: ${result.getMessage}")
        Utils.debug(result)
        result
    }

    def isFileUsed(target: String,
        applyConfiguration: ApplyConfiguration = EtcdStore.getApplyConfig,
        nodes: Vector[NodeConfiguration] = EtcdStore.getNodes.values.toVector): Boolean = {
        nodes.exists(n => applyConfiguration.placements.get(n.placement).fold(false) {
            p =>
                p.services.exists(s => {
                    val service = applyConfiguration.services(s._1)
                    service.files.fold(false) {
                        files => files.exists(f => f._1 == target)
                    }
                })
        })
    }

    private def generateTerraformConfig(
        applyConfig: ApplyConfiguration, nodes: Iterable[NodeConfiguration], editions: Map[String, Long]) = {

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
                                s",\n    ${Utils.quote(s"${i._2.env}=${i._1}.clusterlite.local")}"
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
                    "VOLUME_FILES" -> {
                        val volumes = service.files.getOrElse(Map()).map(f => {
                            val dest = if (f._2.startsWith("/")) {
                                f._2
                            } else {
                                s"/data/${f._2}"
                            }
                            s"${n.volume}/clusterlite-local/${f._1}/${editions(f._1)}" -> dest
                        })
                        volumes.map(v => {
                            s"{ host_path = ${Utils.quote(Utils.backslash(v._1))}, " +
                                s"container_path = ${Utils.quote(Utils.backslash(v._2))}, " +
                                s"read_only = true }"
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
                Utils.warn(s"""
                       [${n.nodeId}] '${n.placement}' placement, required by the '${n.weaveNickName}' node,
                        is not defined in the apply configuration, skipping the node
                    """.stripMargin)
                ""
            }){p => generatePerNode(n, p)}
        }).mkString("\n")
        Utils.debug(s"Generated terraform configuration:\n$result")
        result
    }

    private def openNewApplyConfig(configPath: String): ApplyConfiguration = {

        def generateApplyConfigurationErrorDetails(schemaPath: String, keyword: String,
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
                "config parameter points to non-existing or non-accessible file",
                TryErrorMessage(s"touch $configPath && chmod a+r $configPath",
                    "to make sure file exists and has got read permissions")))
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
                        s"config file is not a valid YAML file: $message",
                        NoTryErrorMessage())
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
                throw new ConfigException(Json.arr(generateApplyConfigurationErrorDetails(
                    "#/properties/placements/additionalProperties/properties/services",
                    "required",
                    s"Placement '${p._1}' does not define any reference to a service",
                    p._2.toJson,
                    s"/placements/${p._1}"
                )))
            }
            p._2.services.foreach(s => {
                if (!result.services.contains(s._1)) {
                    throw new ConfigException(Json.arr(generateApplyConfigurationErrorDetails(
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
                if (!result.services.contains(d._1)) {
                    throw new ConfigException(Json.arr(generateApplyConfigurationErrorDetails(
                        "#/properties/services/additionalProperties/properties/dependencies",
                        "reference",
                        s"Dependency '${d._1}' refers to undefined service",
                        s._2.toJson,
                        s"/services/${s._1}"
                    )))
                }
            }))

            val uploadedFiles = EtcdStore.getFiles.keys.toVector
            s._2.files.fold(())(files => files.foreach(f => {
                if (!uploadedFiles.contains(f._1)) {
                    throw new ConfigException(Json.arr(generateApplyConfigurationErrorDetails(
                        "#/properties/services/additionalProperties/properties/files",
                        "reference",
                        s"File '${f._1}' refers to non-existing file. Run 'clusterlite files' for more information",
                        s._2.toJson,
                        s"/services/${s._1}"
                    )))
                }
            }))
        })
        result
    }

    // source: https://stackoverflow.com/questions/6110062/simple-string-template-replacement-in-scala-and-clojure
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
            case ex: InternalErrorException =>
                Utils.error(ex)
                Utils.error(ex.toMessage)
                1
            case ex: BaseException =>
                Utils.error(ex.toMessage)
                1
            case ex: Throwable =>
                Utils.error(ex)
                Utils.error(new InternalErrorException("unhandled exception", ex).toMessage)
                127
        }
    }
}
