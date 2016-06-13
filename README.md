# Blower

A server orchestration tool.

## Synopsis

    blow [OPTION]... [TASK]...

## Description

Blower is a server orchestration tool with a focus on simplicity of design and minimal abstraction.

Unlike competing tools such as ansible, salt, chef, or puppet, blower doesn't provide unnecessary abstractions over existing OS functionality. Where reasonable, task scripts use the same commands as when configuring a server manually.

Incomplete and occasionally incorrect documentation is available at http://nbaum.github.io/blower/

## Options

Execute tasks.

-d directory
    Set working directory.

-I directory
    Add directory to task search path.

-v log_level
    Set debug level. all, trace, debug, info, warn, error, fatal or off.

## Task execution

Blower changes to the working directory, if specified, first.

Tasks are executed in the order specified. There is an implied first task which runs "./Blowfile", if present.

If a task names a directory, then the file `blow.rb` inside that directory is executed.

If a task names a file, or if the task names a file once `.rb` is appended to the file name, it is executed as Ruby code.
