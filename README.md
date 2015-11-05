# Blower

Blower is a server orchestration tool with a focus on simplicity of design and minimal abstraction.

Unlike competing tools such as ansible, salt, chef, or puppet, blower doesn't provide unnecessary asbtractions over existing OS functionality. Where reasonable, task scripts use the same commands as when configuring a server manually.

## Usage

    blow [-d directory] task...

If a directory is specified, blower will change to it before starting.

Tasks are executed in the order specified. There is an implied first task which runs "Blowfile".

The Blowfile will normally be used to configure the hosts that the rest of the tasks operate on.

## Finding tasks

Blower looks for task files first literally and then with .rb appended.

If a task file is a directory, then it searches it for a task with the same basename as the current task. If it finds one, and the directory contains a Blowfile, the Blowfile will be executed first.

**sh** executes a command on the remote host(s), via ssh. The command is executed on all hosts in serial. **sh** does not return until all hosts have finished.

**reboot** reboots each host in serial and waits for it to respond to ssh requests.

**cp** copies a file from the local filesystem to the remote host(s).

**one_host** runs a block of commands on only one host. This is primarily useful for running cluster-wide commands on clustered hosts.

**each_host** runs a block of commands on each host in serial. This should be used if you need to customize commands for each host.
