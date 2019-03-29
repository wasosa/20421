# Pillar render error breaks state.apply

## The Problem

A pillar render error that happens during the minion initialization
prevents a call to state.apply from succeeding even after the cause
for the error is resolved.

The cause for the failure is a missing file; this leads to an error:

    Pillar render error: Specified SLS 'nodes/this-minion' in environment 'base' is not available on the salt master

Sometime after the minion is up and running, the file is generated
and saved to disk. After that, a call to state.apply fails with the
same error. Running state.apply results in a new pillar render that
actually succeeds; and still, state.apply reports this error:

        Data failed to compile:
    ----------
        Pillar failed to render with the following messages:
    ----------
        Specified SLS 'nodes/this-minion' in environment 'base' is not available on the salt master
    ERROR: Minions returned with non-zero exit code

We initially found that pillar_refresh made the failure go away
and chalked it up to salt misbehaving or not living up to its promise that
state.apply would fetch its own pillar. After much debugging we found that
the pillar render triggered by state.apply, in fact, succeeds.

The problem is that, in `sls()` in salt/modules/state.py,
`__opts__['pillar']['_errors']` contains the error encountered in the intial
pillar render. The render that is triggered from `sls()` succeeds, but does
not clear the error. So, when `sls()` checks for pillar errors, it also fails.

I was unable to figure out why this happens (how the error gets left behind),
and how pillar_refresh clears it.

## Version details
```
Salt Version:
           Salt: 2019.2.0

Dependency Versions:
           cffi: Not Installed
       cherrypy: Not Installed
       dateutil: 2.4.2
      docker-py: Not Installed
          gitdb: 0.6.4
      gitpython: 1.0.1
          ioflo: Not Installed
         Jinja2: 2.8
        libgit2: Not Installed
        libnacl: Not Installed
       M2Crypto: Not Installed
           Mako: Not Installed
   msgpack-pure: Not Installed
 msgpack-python: 0.4.6
   mysql-python: Not Installed
      pycparser: Not Installed
       pycrypto: 2.6.1
   pycryptodome: Not Installed
         pygit2: Not Installed
         Python: 3.5.2 (default, Nov 12 2018, 13:43:14)
   python-gnupg: 0.3.8
         PyYAML: 3.11
          PyZMQ: 15.2.0
           RAET: Not Installed
          smmap: 0.9.0
        timelib: Not Installed
        Tornado: 4.2.1
            ZMQ: 4.1.4

System Versions:
           dist: Ubuntu 16.04 xenial
         locale: ANSI_X3.4-1968
        machine: x86_64
        release: 4.15.0-39-generic
         system: Linux
        version: Ubuntu 16.04 xenial
```

## Reproducing the problem

Clone https://github.com/wasosa/pillar-render-error and then run:

    docker build -t salt . && docker run --rm -ti --name salt salt

This will build a docker image which includes everything needed to
reproduce the problem and will run through all the steps to demo it.
See https://github.com/wasosa/pillar-render-error/blob/master/bootstrap.

## Our usecase

We're using a thin wrapper around salt for configuration management of our
own product. In our case, we had the call to refresh_pillar before the first
call to state.apply, but that wasn't synchronous in our version of salt
(2018.9) so we had a race condition. During automated tests, we found that this
initial state.apply failed sometimes, on slow test machines.

The reason we hit this situation in the first place, is that we use salt to
collect the settings to populate the missing pillar file. This is a sort of
bootstrap scenario for us, and the fix we're considering at the moment is to
create an empty copy of that file to avoid the initial pillar render error.

## The question

The confusion here comes from the fact that state.apply invokes a successful
pillar render but still fails with a pillar render error. That seems wrong.
I dont' understand enough about how/when `__opts__` is manipulated to say
definitively that this is a bug, but it feels like it. If not, I would really
appreciate any help in understanding the expected behavior and/or reasoning
behind it.

I was also able to avoid the failure for state.apply by doing something silly
like this at the top of `sls()` (just for debugging, of course):

    if 'pillar' in __opts__ and '_errors' in __opts__['pillar']:
        __opts__['pillar']['_errors'] = []

