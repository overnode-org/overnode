import java.nio.file.{Files, Paths}

import sbt.project

val solutionName = "cade"

lazy val cade = (project in file("."))
    // general settings
    .settings(
        name := solutionName,
        version := Files.readAllLines(Paths.get("./cade.sh")).get(16).replace("version_system=", ""),
        scalaVersion := "2.12.2",

        // Warn more and treat warnings as errors:
        scalacOptions ++= Seq("-unchecked", "-deprecation", "-feature", "-Xfatal-warnings"),
        // Enable basic linter which injects into the compiler:
        addCompilerPlugin("org.psywerx.hairyfotr" %% "linter" % "0.1.17")
    )
    // 3rd party dependencies
    .settings(
        // for https://github.com/eclipsesource/play-json-schema-validator
        resolvers += "emueller-bintray" at "http://dl.bintray.com/emueller/maven",
        libraryDependencies ++= Seq(
            // wrapper for slf4j - convenient logging api
            "com.typesafe.scala-logging" %% "scala-logging" % "3.5.0",
            // default logging backend - output to stdout
            // replace by another logging backend: https://github.com/typesafehub/scala-logging#prerequisites
            "ch.qos.logback" % "logback-classic" % "1.2.3",
            // CLI arguments parser
            "com.github.scopt" %% "scopt" % "3.5.0",
            // framework for unit tests
            "org.scalatest" %% "scalatest" % "3.0.3" % "test",
            // json parser/renderer library
            "com.typesafe.play" %% "play-json" % "2.6.0-M7",
            // json-schema validator
            "com.eclipsesource" %% "play-json-schema-validator" % "0.9.0",
            // yaml parser
            "com.fasterxml.jackson.dataformat" % "jackson-dataformat-yaml" % "2.8.7",
            // http client
            "org.scalaj" %% "scalaj-http" % "2.3.0",
            // docker client
            "com.github.docker-java" % "docker-java" % "3.0.10"
        )
    )
    // sbt test and sbt run settings
    .settings(
        parallelExecution in Test := false,
        fork in test := true,
        // to make sure alpn setting can be set for JVM
        fork in run := true,
        // to make sure sbt run propogates CTRL-C to the server
        connectInput in run := true
    )
    // package command
    .enablePlugins(JavaAppPackaging)
    .settings(
        mainClass := Some("works.cade.Main"),
        mainClass in (Compile) := Some("works.cade.Main"),
        publishArtifact in (Compile, packageDoc) := false,
        publishArtifact in packageDoc := false,
        scriptClasspath := Seq("*"),
        topLevelDirectory := Some(packageName.value)
    )
