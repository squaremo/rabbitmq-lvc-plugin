# Last value caching exchange

This is a pretty simple implementation of a last value cache using
RabbitMQ's pluggable exchange types feature.

The last value cache is intended to solve problems like the following:
say I am using messaging to send notifications of some changing values
to clients; now, when a new client connects, it won't know the value
until it changes.

The last value exchange acts like a direct exchange (binding keys are
compared for equality with routing keys); but, it also keeps track of
the last value that was published with each routing key, and when a
queue is bound, it automatically enqueues the last value for the
binding key.

## Supported RabbitMQ Versions

The most recent release of this plugin targets RabbitMQ 3.12.x.

## Supported Erlang/OTP Versions

Latest version of this plugin [requires Erlang 25.0 or later versions](https://www.rabbitmq.com/which-erlang.html), same as RabbitMQ 3.12.x.

## Installation

Binary builds of this plugin from
the [Community Plugins page](https://www.rabbitmq.com/community-plugins.html).

See [Plugin Installation](https://www.rabbitmq.com/installing-plugins.html) for details
about how to install plugins that do not ship with RabbitMQ.

## Building from Source

You can build and install it like any other plugin (see
[the plugin development guide](https://www.rabbitmq.com/plugin-development.html)).

## Usage

To use the LVC exchange, with e.g., py-amqp:

    import amqplib.client_0_8 as amqp
    ch = amqp.Connection().channel()
    ch.exchange_declare("lvc", type="x-lvc")
    ch.basic_publish(amqp.Message("value"),
                     exchange="lvc", routing_key="rabbit")
    ch.queue_declare("q")
    ch.queue_bind("q", "lvc", "rabbit")
    print ch.basic_get("q").body

## Limitations

### "Recent value cache"

Message publishing in AMQP 0-9-1 is asynchronous by design and thus introduces natural race conditions
when there's more than one publisher.  It is quite possible to see different
last-values but the same subsequent message stream, from different
clients.

This won't matter if you simply want to have a value to show until you
get an update.  If it does matter, consider e.g. using sequence IDs so you
can notice out-of-order messages.

There's also a race in the pluggable exchanges hook, so that clients
can "see" the binding before the hook has been run; for the LVC, this
means that there's a possiblity that messages will get queued before
the last value.  For this reason, I'm thinking of tagging the last
value messages so that clients can fast-forward to it, or ignore it,
if necessary.

### Values v. deltas

One question that springs to mind when considering last value caches
is "what if I'm sending deltas rather than the whole value?".  The
LVC exchange doesn't address this use case, but you could do it by
using two exchanges and posting full values to the LVC (from the
originating process -- presumably you'd be using deltas to save on
downstream bandwidth).

### Direct exchanges only

The semantics of another kind of value-caching exchange (other than
fanout) aren't obvious.  To choose one option though, say a
newly-bound queue was to be given all values that match its binding
key -- this would require every supported exchange type to supply a
reverse routing match procedure.

## Creating a Release

1. Update `broker_version_requirements` in `helpers.bzl` & `Makefile` (Optional)
1. Update the plugin version in `MODULE.bazel`
1. Push a tag (i.e. `v3.12.0`) with the matching version
1. Allow the Release workflow to run and create a draft release
1. Review and publish the release
