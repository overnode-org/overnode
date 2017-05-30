//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.io.{ByteArrayOutputStream, File}
import java.net.InetAddress
import java.util.NoSuchElementException

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import play.api.libs.json.{JsArray, JsObject, Json}

import scala.util.Try

trait AllCommandOptions {
    val isDryRun: Boolean
}

case class InstallCommandOptions(
    isDryRun: Boolean = false,
    command: String = "help",
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
            parser.parse(opts, d).fold(throw new ParseException())(c => {
                val result = action(c)
                if (c.isDryRun) {
                    Main.wrapEcho(result)
                } else {
                    result
                }
            })
        }

        command match {
            case "help" | "--help" | "-help" | "-h" => helpCommand
            case "version" | "--version" | "-version" | "-v" => versionCommand
            case "install" =>
                val d = InstallCommandOptions()
                val parser = new scopt.OptionParser[InstallCommandOptions]("clusterlite install") {
                    help("help")
                    opt[Unit]("dry-run")
                        .action((x, c) => c.copy(isDryRun = true))
                        .maxOccurs(1)
                        .text("If set, the action will not initiate an action\n" +
                            s"but will print the script of intended actions. Default ${d.isDryRun}")
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
                            s"Default ${d.seeds}")
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
            case i: String =>
                helpCommand
                throw new ParseException(s"Error: $i is unknown command\n" +
                    "Try --help for more information.")
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

    private def helpCommand: String = {
        // TODO implement
        //        apply     Aligns current cluster state with configuration:
        //            starts newly added machines, terminates removed machines and volumes
        """Usage: clusterlite help
          |       clusterlite --help
          |       clusterlite <command> --help
          |
          |Commands:
          |       help      Prints this message
          |       version   Print version information
          |       install   Provisions the current host and joins the cluster
          |""".stripMargin
    }

    private def versionCommand: String = {
        "Webintrinsics Clusterlite, version 0.1.0"
    }
}

object Main extends App {
    private def wrapEcho(str: String): String = {
        s"\n$str\n"
    }

    val app = new Main()
    try {
        System.out.print(app.run(args.toVector))
        System.out.print("\n")
    } catch {
        case ex: ErrorException =>
            System.out.print(s"failure: ${ex.getMessage}\n")
            System.exit(1)
        case ex: ParseException =>
            if (ex.getMessage.isEmpty) {
                System.out.print("failure: invalid arguments\n")
            } else {
                System.out.print(s"${ex.getMessage}failure: invalid arguments\n")
            }
            System.exit(2)
        case ex: Throwable =>
            val out = new ByteArrayOutputStream
            Console.withErr(out) {
                ex.printStackTrace()
            }
            System.out.print(s"${out}\nfailure: internal error, please report to https://github.com/webintrinsics/clusterlite")
            System.exit(3)
    }
}
