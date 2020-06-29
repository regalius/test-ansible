# Cgroup

# How to run
```
# first attempt
$ vagrant up 

# second attempt
$ vagrant up --provision
```

Sample Result
```
➜ vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Checking if box 'ubuntu/trusty64' version '14.04' is up to date...
==> default: Running provisioner: ansible_local...
    default: Running ansible-playbook...

PLAY [local] *******************************************************************

TASK [Gathering Facts] *********************************************************
ok: [127.0.0.1]

TASK [Install dependencies package cgroups] ************************************
[WARNING]: Consider using the apt module rather than running 'apt-get'.  If you
need to use command because apt is insufficient you can add 'warn: false' to
this command task or set 'command_warnings=False' in ansible.cfg to get rid of
this message.
changed: [127.0.0.1]

TASK [cgroup : Copy file cgconfig script] **************************************
ok: [127.0.0.1]

TASK [cgroup : Copy file cgrules conf] *****************************************
changed: [127.0.0.1]

TASK [Copy file cgroup script] *************************************************
ok: [127.0.0.1]

TASK [Execute cgroup script] ***************************************************
changed: [127.0.0.1]

PLAY RECAP *********************************************************************
127.0.0.1                  : ok=6    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```