export async

import Base: close
import Base: show

"""
    async()

Creates an async operator, which sends items from the source Observable asynchronously.

# Producing

Stream of type `<: Subscribable{L}` where `L` refers to type of source stream

See also: [`AbstractOperator`](@ref), [`InferableOperator`](@ref), [`ProxyObservable`](@ref)
"""
async() = AsyncOperator()

struct AsyncOperator <: InferableOperator end

function on_call!(::Type{L}, ::Type{L}, operator::AsyncOperator, source) where L
    return proxy(L, source, AsyncProxy{L}())
end

operator_right(operator::AsyncOperator, ::Type{L}) where L = L

struct AsyncProxy{L} <: ActorSourceProxy end

actor_proxy!(proxy::AsyncProxy{L},  actor::A)  where { L, A } = AsyncActor{L, A}(actor)
source_proxy!(proxy::AsyncProxy{L}, source::S) where { L, S } = AsyncObservable{L, S}(source)

struct AsyncDataMessage{L}
    data :: L
end

struct AsyncErrorMessage
    err
end

struct AsyncCompleteMessage end

const AsyncMessage{L} = Union{AsyncDataMessage{L}, AsyncErrorMessage, AsyncCompleteMessage}

struct AsyncCompletionException <: Exception end

mutable struct AsyncActor{L, A} <: Actor{L}
    is_cancelled :: Bool
    actor        :: A
    channel      :: Channel{AsyncMessage{L}}

    AsyncActor{L, A}(actor::A) where L where A = begin
        channel = Channel{AsyncMessage{L}}(1)
        self    = new(false, actor, channel)

        task = @async begin
            try
                while !self.is_cancelled
                    message = take!(channel)::AsyncMessage{L}
                    __process_async_message(self, message)
                end
            catch err
                if !(err isa AsyncCompletionException)
                    __process_async_message(self, AsyncErrorMessage(err))
                end
            end
        end

        bind(channel, task)

        return self
    end
end

__process_async_message(actor::AsyncActor{L}, message::AsyncDataMessage{L}) where L = begin next!(actor.actor, message.data); end
__process_async_message(actor::AsyncActor,    message::AsyncErrorMessage)           = begin error!(actor.actor, message.err); close(actor); end
__process_async_message(actor::AsyncActor,    message::AsyncCompleteMessage)        = begin complete!(actor.actor); close(actor); end

is_exhausted(actor::AsyncActor) = actor.is_cancelled || is_exhausted(actor.actor)

on_next!(actor::AsyncActor{L}, data::L) where L = begin !actor.is_cancelled && begin put!(actor.channel, AsyncDataMessage{L}(data)); yield(); end end
on_error!(actor::AsyncActor{L}, err)    where L = begin !actor.is_cancelled && begin put!(actor.channel, AsyncErrorMessage(err)); yield() end end
on_complete!(actor::AsyncActor{L})      where L = begin !actor.is_cancelled && begin put!(actor.channel, AsyncCompleteMessage()); yield() end end

Base.close(actor::AsyncActor) = close(actor.channel, AsyncCompletionException())

struct AsyncObservable{L, S} <: Subscribable{L}
    source :: S
end

function on_subscribe!(observable::AsyncObservable, actor::AsyncActor)
    event        = Base.Event()
    subscription = Ref{Any}(nothing)

    @async begin
        if !actor.is_cancelled
            try
                subscription[] = subscribe!(observable.source, actor)
            catch _
                subscription[] = VoidTeardown()
            end
        end
        notify(event)
    end

    return AsyncSubscription(event, actor, subscription)
end

struct AsyncSubscription{A} <: Teardown
    event        :: Base.Event
    actor        :: A
    subscription :: Base.RefValue{Any}
end

as_teardown(::Type{<:AsyncSubscription}) = UnsubscribableTeardownLogic()

function on_unsubscribe!(subscription::AsyncSubscription)
    try
        if !subscription.actor.is_cancelled
            close(subscription.actor)
        end

        subscription.actor.is_cancelled = true

        wait(subscription.event)

        unsubscribe!(subscription.subscription[])
    catch _
    end
    return nothing
end

Base.show(io::IO, operator::AsyncOperator)                 = print(io, "AsyncOperator()")
Base.show(io::IO, proxy::AsyncProxy{L})            where L = print(io, "AsyncProxy($L)")
Base.show(io::IO, actor::AsyncActor{L})            where L = print(io, "AsyncActor($L)")
Base.show(io::IO, observaable::AsyncObservable{L}) where L = print(io, "AsyncObservable($L)")
Base.show(io::IO, subscription::AsyncSubscription)         = print(io, "AsyncSubscription()")