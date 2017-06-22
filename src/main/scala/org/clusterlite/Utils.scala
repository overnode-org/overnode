//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.io.{BufferedWriter, File, FileWriter, PrintWriter}
import java.nio.file.{Files, Paths}
import java.security.MessageDigest

import play.api.libs.json.JsString

import scala.io.Source
import scala.sys.process.ProcessLogger

object Utils {
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

    def writeToFile(content: String, destination: String): Unit = {
        try {
            val pw = new PrintWriter(new File(destination))
            pw.write(content)
            pw.close
        } catch {
            case ex: Throwable => throw new EnvironmentException(
                s"failure to write to $destination file: ${ex.getMessage}")
        }
    }

    case class ProcessResult(cmd: String, cwd: String, out: String, err: String, code: Int) {
        def ensureCode(printLogs: Boolean = true): Unit = {
            if (code != 0) {
                if (printLogs) {
                    print(out)
                    print(err)
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

    def runProcessNonInteractive(cmd: String, cwd: String, writeConsole: Boolean = true): ProcessResult = {
        val process = scala.sys.process.Process(cmd, new File(cwd))


        val bufOut = new StringBuilder
        val bufErr = new StringBuilder

        val code = process.run(
            new ProcessLogger {
                override def buffer[T](f: => T) = f

                override def out(s: => String) = {
                    if (writeConsole) {
                        System.out.println(s)
                    }
                    bufOut.append(s)
                    bufOut.append("\n")
                }

                override def err(s: => String) =  {
                    if (writeConsole) {
                        System.err.print(s)
                        System.err.print("\n")
                    }
                    bufErr.append(s)
                    bufErr.append("\n")
                }
            },
            false)
        ProcessResult(cmd, cwd, bufOut.toString(), bufErr.toString(), code.exitValue())
    }
}
