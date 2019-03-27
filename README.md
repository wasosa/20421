# Initial pillar render failure breaks state.apply until pillar_refresh

## Reproducing the problem

You can simply run:

    docker build -t salt . && docker run --rm -ti --name salt salt

This will build a docker image which includes everything needed to reproduce
the problem. We initially found that pillar_refresh made the failure go away
and chalked it up to salt misbehaving or not living up to its promise that
state.apply would fetch its own pillar. After much debugging we found that
the pillar render triggered by state.apply, in fact, succeeds.

The problem is that, in `sls()` in salt/modules/state.py,
`__opts__['pillar']['_errors']` contains the error encountered in the intial
pillar render. The render that is triggered from `sls()` succeeds, but does
not clear the error. So, when `sls()` checks for pillar errors, it also fails.

I was unable to figure out why this happens (how the error gets left behind),
and how pillar_refresh clears it.

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

