//
// License: https://github.com/cadeworks/cade/blob/master/LICENSE
//

package works.cade

import java.io.{File, PrintWriter}
import java.nio.file.{Files, Paths}

import play.api.libs.json.JsString

import scala.io.Source
import scala.sys.process.ProcessLogger

object Utils {

    var isDebugOn = false

    def debug(str: String): Unit = {
        if (isDebugOn) {
            System.err.println(str.gray)
        }
    }

    def debug(ex: Throwable): Unit = {
        if (isDebugOn) {
            System.err.print(ConsoleColorize.GRAY)
            ex.printStackTrace()
            System.err.print(ConsoleColorize.WHITE)
        }
    }

    def info(str: String): Unit = {
        System.err.println(str.gray)
    }

    def status(str: String): Unit = {
        System.err.println(str)
    }

    def warn(str: String): Unit = {
        System.err.println(str.yellow)
    }

    def print(str: String): Unit = {
        System.out.print(str)
    }

    def println(str: String): Unit = {
        System.out.println(str)
    }

    def error(str: String): Unit = {
        System.err.println(str.red)
    }

    def error(ex: Throwable): Unit = {
        System.err.print(ConsoleColorize.RED)
        ex.printStackTrace()
        System.err.print(ConsoleColorize.WHITE)
    }

    def quote(str: String): String = {
        "\"" + str + "\""
    }
    def backslash(str: String): String = {
        JsString(str).toString().drop(1).dropRight(1)
    }
    def dashIfEmpty(str: String): String = {
        if (str.isEmpty) {
            "-"
        } else {
            str
        }
    }

    def loadFromResource(resource: String): String = {
        val source = Source.fromURL(getClass.getResource(s"/$resource"))
        source.getLines().mkString("\n").replaceAll("\r\n", "\n")
    }

    def loadFromFile(dir: String, resource: String): String = {
        new String(Files.readAllBytes(Paths.get(s"$dir/$resource")))
    }

    def loadFromFileIfExists(dir: String, resource: String): Option[String] = {
        val path = Paths.get(s"$dir/$resource")
        if (path.toFile.exists()) {
            Some(new String(Files.readAllBytes(path)))
        } else {
            None
        }
    }

    def loadFromFileIfExistsBase64Encoded(dir: String, resource: String): Option[String] = {
        val path = Paths.get(s"$dir/$resource")
        if (path.toFile.exists()) {
            val encoded = runProcessNonInteractive(Vector("base64", resource), dir, writeConsole = Utils.isDebugOn)
            encoded.ensureCode()
            Some(encoded.out)
        } else {
            None
        }
    }

    def printFromFileIfExistsBase64Decoded(dir: String, resource: String): Int = {
        val path = Paths.get(s"$dir/$resource")
        if (path.toFile.exists()) {
            runProcessInteractive(Vector("base64", "-d", resource), dir)
        } else {
            1
        }
    }

    def writeToFile(content: String, destination: String): Unit = {
        try {
            val pw = new PrintWriter(new File(destination))
            pw.write(content)
            pw.close()
        } catch {
            case ex: Throwable => throw new PrerequisitesException(
                s"failure to write to $destination file: ${ex.getMessage}",
                NoTryErrorMessage())
        }
    }

    def loadHostsFileIfExists(dir: String, resource: String): Map[String, Vector[String]] = {
        loadFromFileIfExists(dir, resource).map(content => {
            content.lines.toVector
                .map(i => i.trim)
                .filter(i => !i.startsWith("#") && i.nonEmpty)
                .flatMap(i => {
                    val words = i.split("\\s+")
                    val ip_address = words.head
                    val names = words.drop(0).toVector
                    names.map(j => j -> ip_address)
                })
                .groupBy(i => i._1)
                .map(i => i._1 -> i._2.map(j => j._2))
        }).getOrElse(Map())
    }

    case class ProcessResult(cmd: Vector[String], cwd: String, out: String, err: String, code: Int) {
        def ensureCode(printLogs: Boolean = true): Unit = {
            if (code != 0) {
                if (printLogs) {
                    print(out)
                    error(err)
                }
                throw new InternalErrorException(s"failure to execute '$cmd' in '$cwd' directory")
            }
        }
    }

    def runProcessInteractive(cmd: String, cwd: String): Int = {
        val process = scala.sys.process.Process(cmd, new File(cwd))
        val code = process.run(true)
        code.exitValue()
    }

    def runProcessInteractive(cmd: Vector[String], cwd: String): Int = {
        val process = scala.sys.process.Process(cmd, new File(cwd))
        val code = process.run(true)
        code.exitValue()
    }

    def runProcessNonInteractive(cmd: Vector[String], cwd: String, writeConsole: Boolean = true): ProcessResult = {
        val process = scala.sys.process.Process(cmd, new File(cwd))


        val bufOut = new StringBuilder
        val bufErr = new StringBuilder

        val code = process.run(
            new ProcessLogger {
                override def buffer[T](f: => T): T = f

                override def out(s: => String): Unit = {
                    if (writeConsole) {
                        System.out.println(s)
                    }
                    bufOut.append(s)
                    bufOut.append("\n")
                }

                override def err(s: => String): Unit =  {
                    if (writeConsole) {
                        System.err.println(s)
                    }
                    bufErr.append(s)
                    bufErr.append("\n")
                }
            },
            connectInput = false)
        val exitCode = code.exitValue() // blocks until process exists, this guarantees output buffer is captured full
        ProcessResult(cmd, cwd, bufOut.toString(), bufErr.toString(), exitCode)
    }

    implicit class ConsoleColorize(val str: String) {
        import ConsoleColorize._

        def black     = s"$BLACK$str$WHITE"
        def red       = s"$RED$str$WHITE"
        def green     = s"$GREEN$str$WHITE"
        def yellow    = s"$YELLOW$str$WHITE"
        def blue      = s"$BLUE$str$WHITE"
        def magenta   = s"$MAGENTA$str$WHITE"
        def cyan      = s"$CYAN$str$WHITE"
        def white     = s"$WHITE$str$WHITE"
        def gray      = s"$GRAY$str$WHITE"
    }

    object ConsoleColorize {
        // can not use Console.COLOR because it does not reset brightness properly
        // so define correct working colors below
        val BLACK     = "\u001b[0;30m"
        val GRAY      = "\u001b[1;30m"
        val RED       = "\u001b[0;31m"
        val RED_L     = "\u001b[1;31m"
        val GREEN     = "\u001b[0;32m"
        val GREEN_L   = "\u001b[1;32m"
        val YELLOW    = "\u001b[0;33m"
        val YELLOW_L  = "\u001b[1;33m"
        val BLUE      = "\u001b[0;34m"
        val BLUE_L    = "\u001b[1;34m"
        val MAGENTA   = "\u001b[0;35m"
        val MAGENTA_L = "\u001b[1;35m"
        val CYAN      = "\u001b[0;36m"
        val CYAN_L    = "\u001b[1;36m"
        val WHITE     = "\u001b[0;37m"
        val WHITE_L   = "\u001b[1;37m"
    }
}
