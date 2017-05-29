//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.io.File
import java.net.InetAddress
import java.util.NoSuchElementException

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import play.api.libs.json.{JsArray, JsObject, Json}

import scala.util.Try

trait AllCommandOptions {
    val isDryRun: Boolean
//    val provider: Providers.Value

//    val rootDirectoryPath: String = Option(new File(config).getAbsoluteFile.getParent).getOrElse("./")
//    val rootFileName: String = new File(config).getAbsoluteFile.getName
//    val rootFilePath: String = new File(config).getAbsoluteFile.getPath
//
//    val stateDirectoryName: String = ".wi-cluster"
//    val stateDirectoryPath: String = new File(rootDirectoryPath, stateDirectoryName).getPath
}
//
case class InstallCommandOptions(
    isDryRun: Boolean = false,
    token: String = "",
    name: String = Option(System.getenv("HOSTNAME")).getOrElse(""),
    seeds: String = Option(System.getenv("HOSTNAME_I")).getOrElse(""),
    publicAddress: String = "",
    dataDirectory: String = "/var/clusterlite") extends AllCommandOptions {
    override def toString: String = {
        s"""[
          |#    dry-run=$isDryRun
          |#    token=$token
          |#    name=$name
          |#    seeds=$seeds
          |#    public-address=$publicAddress
          |#    data-directory=$dataDirectory
          |#]""".stripMargin
    }
}

//
//trait AllCommandOptionsWithInferredProvider extends AllCommandOptions {
//    lazy val rootFileData: JsObject = {
//        try {
//            val yamlReader = new ObjectMapper(new YAMLFactory())
//            val obj = yamlReader.readValue(new File(rootFilePath), classOf[Object])
//            val jsonWriter = new ObjectMapper()
//            val json = jsonWriter.writeValueAsString(obj)
//            Json.parse(json).as[JsObject]
//        } catch {
//            case ex: Throwable => throw new ErrorException(s"invalid configuration file: $ex")
//        }
//    }
//
//    lazy val provider: Providers.Value = {
//        try {
//            val providerName = (rootFileData \ "provider").get.as[String]
//            try {
//                Providers.withName(providerName)
//            } catch {
//                case _: NoSuchElementException =>
//                    throw new ErrorException(s"invalid configuration file: unknown provider $providerName")
//            }
//        } catch {
//            case ex: Throwable => throw new ErrorException(s"invalid configuration file: $ex")
//        }
//    }
//}
//
//case class StartStopCommandOptions(
//    config: String = "./cluster.yaml") extends AllCommandOptionsWithInferredProvider
//
//case class SshCommandOptions(
//    config: String = "./cluster.yaml",
//    machine: String = "m1") extends AllCommandOptionsWithInferredProvider
//
//case class ExecuteCommandOptions(
//    config: String = "./cluster.yaml",
//    command: String = "hostname") extends AllCommandOptionsWithInferredProvider
//

class ErrorException(msg: String) extends Exception(msg)
class ParseException(msg: String = "") extends Exception(msg)
class ConfigException(errors: JsArray)
    extends ErrorException(s"invalid configuration file: errors:\n${Json.prettyPrint(errors)}")

class Main {

    private var runargs: Vector[String] = Nil.toVector

    private def run(args: Vector[String]): String = {
        runargs = args
        val command = args.headOption.getOrElse("help")
        val opts = args.drop(1)
        doCommand(command, opts)
    }

    private def doCommand(command: String, opts: Vector[String]): String = { //scalastyle:ignore

        def run[A <: AllCommandOptions](parser: scopt.OptionParser[A], d: A, action: (A) => String) = {
            parser.parse(opts, d).fold(throw new ParseException)(c => {
                val result = action(c)
                if (c.isDryRun) {
                    "echo \"\n" + result + "\"\n"
                } else {
                    result
                }
            })
        }

        command match {
            case "help" | "--help" | "-help" | "-h" => helpCommand
            case "version" | "--version" | "-version" | "-v" => helpCommand
            case "install" =>
                val d = InstallCommandOptions()
                val parser = new scopt.OptionParser[InstallCommandOptions]("clusterlite init") {
                    help("help")
                    opt[Boolean]("dry-run")
                        .action((x, c) => c.copy(isDryRun = x))
                        .maxOccurs(1)
                        .text(s"If set/true, the action will not initiate an action but will print the script of intended actions. Default ${
                            d.isDryRun
                        }")
                    opt[String]("name")
                        .action((x, c) => c.copy(name = x))
                        .maxOccurs(1)
                        .text(s"Name of a node. It can be any string but it should be unique within the scope of the cluster. Default ${d.name}")
                    opt[String]("token")
                        .required()
                        .maxOccurs(1)
                        .validate(c => if (c.length < 16) {
                            failure("token parameter should be at least 16 characters long")
                        } else {
                            success
                        })
                        .action((x, c) => c.copy(token = x))
                        .text(s"Cluster secret key. It is used for inter-node traffic encryption. Default ${d.token}")
                    opt[String]("seeds")
                        .action((x, c) => c.copy(seeds = x))
                        .maxOccurs(1)
                        .text("IP addresses or hostnames of seed nodes separated by comma. " +
                            "This should be the same value for all nodes joining the cluster. " +
                            "It is NOT necessary to enumerate all nodes in the cluster as seeds. " +
                            "For high-availability it should include 3 or 5 nodes. " +
                            s"Default ${d.name}")
                    opt[String]("data-directory")
                        .action((x, c) => c.copy(dataDirectory = x))
                        .maxOccurs(1)
                        .validate(c => if (c.isEmpty) {
                            failure("data-directory should be non empty path")
                        } else {
                            success
                        })
                        .text(s"Path to a directory where the node will persist data. Default ${d.dataDirectory}")
                    opt[String]("public-address")
                        .action((x, c) => c.copy(publicAddress = x))
                        .maxOccurs(1)
                        .text("Public IP address of the node, if exists or requires exposure. " +
                            "This can be assigned later with help of set command. Default not assigned")
                }
                run(parser, d, installCommand)
//            case "start" =>
//                val d = StartStopCommandOptions()
//                val parser = new scopt.OptionParser[StartStopCommandOptions]("wi-cluster start") {
//                    help("help")
//                    opt[String]("config")
//                        .action((x, c) => c.copy(config = x))
//                        .text(s"Target configuration file to read. Default ${d.config}")
//                }
//                run(parser, d, startCommand)
//            case "stop" =>
//                val d = StartStopCommandOptions()
//                val parser = new scopt.OptionParser[StartStopCommandOptions]("wi-cluster stop") {
//                    help("help")
//                    opt[String]("config")
//                        .action((x, c) => c.copy(config = x))
//                        .text(s"Target configuration file to read. Default ${d.config}")
//                }
//                run(parser, d, stopCommand)
//            case "destroy" =>
//                val d = StartStopCommandOptions()
//                val parser = new scopt.OptionParser[StartStopCommandOptions]("wi-cluster destroy") {
//                    help("help")
//                    opt[String]("config")
//                        .action((x, c) => c.copy(config = x))
//                        .text(s"Target configuration file to read. Default ${d.config}")
//                }
//                run(parser, d, destroyCommand)
//            case "ssh" =>
//                val d = SshCommandOptions()
//                val parser = new scopt.OptionParser[SshCommandOptions]("wi-cluster ssh") {
//                    help("help")
//                    opt[String]("config")
//                        .action((x, c) => c.copy(config = x))
//                        .text(s"Target configuration file to read. Default ${d.config}")
//                    opt[String]("machine")
//                        .action((x, c) => c.copy(machine = x))
//                        .text(s"Target machine name. Default ${d.config}")
//                }
//                run(parser, d, sshCommand)
//            case "execute" =>
//                val d = ExecuteCommandOptions()
//                val parser = new scopt.OptionParser[ExecuteCommandOptions]("wi-cluster execute") {
//                    help("help")
//                    opt[String]("config")
//                        .action((x, c) => c.copy(config = x))
//                        .text(s"Target configuration file to read. Default ${d.config}")
//                    opt[String]("command")
//                        .action((x, c) => c.copy(command = x))
//                        .text(s"Command to execute. Default ${d.config}")
//                }
//                run(parser, d, executeCommand)
//            case "status" =>
//                val d = StartStopCommandOptions()
//                val parser = new scopt.OptionParser[StartStopCommandOptions]("wi-cluster status") {
//                    help("help")
//                    opt[String]("config")
//                        .action((x, c) => c.copy(config = x))
//                        .text(s"Target configuration file to read. Default ${d.config}")
//                }
//                run(parser, d, statusCommand)
            case i: String =>
                helpCommand
                Utils.error(s"$i is unknown command")
        }
    }

    private def installCommand(config: InstallCommandOptions): String = {
        //seeds parameter can not resolve all hostnames
        //Try --help for more information.

        if (config.seeds.isEmpty) {
            throw new ParseException("Error: seeds parameter should not be empty\n" +
                "Try --help for more information.")
        }
        if (!config.seeds.split(",").forall(i => Try(InetAddress.getByName(i)).isSuccess)) {
            throw new ParseException("Error: failure to resolve all hostnames for seeds parameter\n" +
                "Try --help for more information.")
        }
        val script = Utils.loadFromResource("install.sh")
        script
            .replaceAll("\r\n", "\n")
            .replaceAll("__CONFIG__", "'''" + Json.stringify(Json.obj(
                "name" -> config.name,
                "volume" -> config.dataDirectory,
                "token" -> config.token,
                "seeds" -> config.seeds,
                "publicIp" -> config.publicAddress
            )) + "'''")
            .replaceAll("__TOKEN__", config.token)
            .replaceAll("__NAME__", config.name)
            .replaceAll("__SEEDS__", config.seeds)
            .replaceAll("__PARSED_ARGUMENTS__", config.toString)
            .replaceAll("__COMMAND__", s"clusterlite ${runargs.mkString(" ")}")
            .replaceAll("__PUBLIC_ADDRESS__", config.publicAddress)
            .replaceAll("__VOLUME__", config.dataDirectory)
            .replaceAll("__LOG__", "[clusterlite install]")
    }
//
//    private def startCommand(config: StartStopCommandOptions): Unit = {
//        Utils.ensureFileExists(config.rootFilePath)
//        Utils.ensureDirectoryExistsOrCreate(config.stateDirectoryPath)
//
//        val provider = Provider(config.provider, config.stateDirectoryPath)
//        provider.validate(config.rootFileData)
//
//        val existingMachines = provider.machines
//        val configuredMachines = (config.rootFileData \ "machines").as[JsObject].fields
//        configuredMachines.filter(i => !existingMachines.contains(i._1)).foreach(i => {
//            provider.create(i._1, i._2.as[JsObject])
//        })
//        configuredMachines.foreach(i => {
//            provider.start(i._1)
//        })
//    }
//
//    private def stopCommand(config: StartStopCommandOptions): Unit = {
//        Utils.ensureFileExists(config.rootFilePath)
//        Utils.ensureDirectoryExistsOrCreate(config.stateDirectoryPath)
//
//        val provider = Provider(config.provider, config.stateDirectoryPath)
//        provider.validate(config.rootFileData)
//
//        provider.machines.foreach(m => {
//            provider.stop(m)
//        })
//    }
//
//    private def destroyCommand(config: StartStopCommandOptions): Unit = {
//        Utils.ensureFileExists(config.rootFilePath)
//        Utils.ensureDirectoryExistsOrCreate(config.stateDirectoryPath)
//
//        val provider = Provider(config.provider, config.stateDirectoryPath)
//        provider.validate(config.rootFileData)
//
//        provider.machines.foreach(m => {
//            provider.terminate(m)
//        })
//    }
//
//    private def sshCommand(config: SshCommandOptions): Unit = {
//        Utils.ensureFileExists(config.rootFilePath)
//        Utils.ensureDirectoryExistsOrCreate(config.stateDirectoryPath)
//
//        val provider = Provider(config.provider, config.stateDirectoryPath)
//        provider.validate(config.rootFileData)
//
//        val existingMachines = provider.machines
//
//        if (!existingMachines.contains(config.machine)) {
//            val configuredMachines = (config.rootFileData \ "machines").as[JsObject].fields.map(i => i._1)
//            if (!configuredMachines.contains(config.machine)) {
//                Utils.error(s"machine ${config.machine} is not defined in the configuration file")
//            }
//            Utils.error(s"machine ${config.machine} has not been started")
//        }
//        provider.ssh(config.machine)
//    }
//
//    private def executeCommand(config: ExecuteCommandOptions): Unit = {
//        Utils.ensureFileExists(config.rootFilePath)
//        Utils.ensureDirectoryExistsOrCreate(config.stateDirectoryPath)
//
//        val provider = Provider(config.provider, config.stateDirectoryPath)
//        provider.validate(config.rootFileData)
//
//        provider.machines.foreach(m => {
//            provider.execute(m, config.command)
//        })
//    }
//
//    private def statusCommand(config: StartStopCommandOptions): Unit = {
//        Utils.ensureFileExists(config.rootFilePath)
//        Utils.ensureDirectoryExistsOrCreate(config.stateDirectoryPath)
//
//        val provider = Provider(config.provider, config.stateDirectoryPath)
//        provider.validate(config.rootFileData)
//
//        // TODO incorporate not created machines
//        provider.machines.foreach(m => {
//            provider.status(m)
//        })
//    }

    private def helpCommand: String = {
        // TODO implement
        //        apply     Aligns current cluster state with configuration:
        //            starts newly added machines, terminates removed machines and volumes
        """
          |Usage: clusterlite help
          |       clusterlite --help
          |       clusterlite <command> --help
          |Commands:
          |       help      Prints this message
          |       version   Print version information
          |       install   Provisions the current host and joins the cluster
        """.stripMargin
    }

    private def versionCommand: String = {
        """
          |Webintrinsics Clusterlite, version 0.1.0
        """.stripMargin
    }
}

object Main extends App {
    val app = new Main()
    try {
        System.out.print(app.run(args.toVector))
    } catch {
        case ex: ErrorException =>
            System.err.print(s"failure: ${ex.getMessage}\n")
            System.exit(1)
        case ex: ParseException =>
            if (ex.getMessage.isEmpty) {
                System.err.print("failure: invalid arguments")
            } else {
                System.err.print(s"${ex.getMessage}\nfailure: invalid arguments\n")
            }
            System.exit(2)
        case ex: Throwable =>
            ex.printStackTrace()
            System.err.print("failure: internal error, please report a bug to https://github.com/webintrinsics/clusterlite\n")
            System.exit(3)
    }
}
