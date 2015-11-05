# Blower

Blower is a server orchestration tool with a focus on simplicity of design and minimal abstraction.

Unlike competing tools such as ansible, salt, chef, or puppet, blower doesn't provide unnecessary abstractions over existing OS functionality. Where reasonable, task scripts use the same commands as when configuring a server manually.

Incomplete and occasionally incorrect documentation is available at http://nbaum.github.io/blower/

## Usage

    blow [-d directory] task...

If a directory is specified, blower will change to it before starting.

Tasks are executed in the order specified. There is an implied first task which runs "Blowfile".

The Blowfile will normally be used to configure the hosts that the rest of the tasks operate on.
