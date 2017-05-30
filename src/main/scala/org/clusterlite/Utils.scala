//
// License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
//

package org.clusterlite

import java.io.{BufferedWriter, File, FileWriter, PrintWriter}
import java.nio.charset.StandardCharsets
import java.nio.file.{Files, Paths}

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory

import scala.io.Source
import scala.sys.process.ProcessLogger

object Utils {
    def quote(str: String): String = {
        "\"" + str + "\""
    }

    def ensureDirectoryExists[B](str: String): Unit = {
        val projectDirectory = new File(str)
        if (!projectDirectory.exists || !projectDirectory.isDirectory) {
            error(s"${str} directory does not exist")
        }
    }

    def ensureFileExists[B](str: String): Unit = {
        val file = new File(str)
        if (!file.exists || file.isDirectory) {
            error(s"${str} file does not exist")
        }
    }

    def ensureDirectoryExistsOrCreate(str: String): Unit = {
        val dir = new File(str)
        if (!dir.exists() && !dir.mkdir()) {
            error(s"permission denied: failed to create the ${dir.toString} directory")
        }
    }

    def error(str: String): Nothing = {
        throw new ErrorException(str)
    }


    def copyFromResource(resource: String, destination: String): Unit = {
        writeToFile(loadFromResource(resource), destination)
    }

    def loadFromResource(resource: String): String = {
        val source = Source.fromURL(getClass.getResource(s"/$resource"))
        source.getLines().mkString("\n")
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
            case ex: Throwable => error(s"failure to write to $destination file: ${ex.getMessage}")
        }
    }

    def deleteRecursively(destination: String): Unit = {
        try {
            val file = new File(destination)
            if (file.isDirectory) {
                Option(file.listFiles).map(i => i.toList).getOrElse(Nil).foreach(i => deleteRecursively(i.getPath))
            }
            file.delete
        } catch {
            case ex: Throwable => error(s"failure to delete ${destination}: ${ex.getMessage}")
        }
    }

    case class ProcessResult(cmd: String, cwd: String, out: String, err: String, code: Int) {
        def ensureCode(printLogs: Boolean = true): Unit = {
            if (code != 0) {
                if (printLogs) {
                    print(out)
                    print(err)
                }
                error(s"failure to execute '$cmd' in '$cwd' directory")
            }
        }
    }

    def ensureInPath(executable: String): Unit = {
        val existsInPath = System.getenv("PATH").split(File.pathSeparator)
            .exists(i => {
                val p = new File(i)
                p.exists() && p.isDirectory && p.listFiles()
                    .exists(f => {
                        val name = f.getName()
                        val shortName = if (name.endsWith(".exe")) {
                            name.dropRight(4)
                        } else {
                            name
                        }
                        name == executable || shortName == executable
                    })
            })
        if (!existsInPath) {
            error(s"$executable is not found in PATH")
        }
    }

    def runProcess(cmd: String, cwd: String,
        writeLog: Boolean = true,
        writeConsole: Boolean = true,
        connectInput: Boolean = false): ProcessResult = {
        val process = scala.sys.process.Process(cmd, new File(cwd))

        val pwOut = if (writeLog) {
            Some(new BufferedWriter(new FileWriter(new File(cwd, "out.txt"), true)))
        } else {
            None
        }
        val pwErr = if (writeLog) {
            Some(new BufferedWriter(new FileWriter(new File(cwd, "err.txt"), true)))
        } else {
            None
        }

        val bufOut = new StringBuilder
        val bufErr = new StringBuilder

        try {
            val code = process.run(
                new ProcessLogger {
                    override def buffer[T](f: => T) = f

                    override def out(s: => String) = {
                        pwOut.fold(())(f => {
                            f.write(s)
                            f.write("\n")
                            f.flush()
                        })
                        if (writeConsole) {
                            System.out.print(s)
                            System.out.print("\n")
                        }
                        bufOut.append(s)
                        bufOut.append("\n")
                    }

                    override def err(s: => String) =  {
                        pwErr.fold(())(f => {
                            f.write(s)
                            f.write("\n")
                            f.flush()
                        })
                        if (writeConsole) {
                            System.err.print(s)
                            System.err.print("\n")
                        }
                        bufErr.append(s)
                        bufErr.append("\n")
                    }
                },
                connectInput)
            ProcessResult(cmd, cwd, bufOut.toString(), bufErr.toString(), code.exitValue())
        }
        finally {
            pwOut.fold(()){f => f.close()}
            pwErr.fold(()){f => f.close()}
        }
    }
}
