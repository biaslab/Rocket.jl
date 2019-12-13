module RxSubscribableTest

using Test
using Suppressor

import Rx
import Rx: SubscribableTrait, ValidSubscribable, InvalidSubscribable
import Rx: Subscribable, as_subscribable
import Rx: subscribe!

@testset "Subscribable" begin

    struct DummyType end

    struct NotImplementedSubscribable <: Subscribable{Int} end

    struct ExplicitlyDefinedSubscribable end
    Rx.as_subscribable(::Type{<:ExplicitlyDefinedSubscribable}) = ValidSubscribable{String}()

    struct ImplementedSubscribable <: Subscribable{Int} end
    function Rx.on_subscribe!(::ImplementedSubscribable, actor)
        return Rx.VoidTeardown()
    end

    @testset "as_subscribable" begin
        # Check if arbitrary dummy type has invalid subscribable type
        @test as_subscribable(DummyType) === InvalidSubscribable()

        # Check if as_subscribable returns valid subscribable type for subtypes of Subscribable abstract type
        @test as_subscribable(NotImplementedSubscribable) === ValidSubscribable{Int}()

        # Check if as_subscribable returns valid subscribable type for explicitly defined types
        @test as_subscribable(ExplicitlyDefinedSubscribable) === ValidSubscribable{String}()
    end

    @testset "subscribe!" begin
        actor = Rx.VoidActor{Int}()

        @test_throws ErrorException subscribe!(DummyType(), actor)
        @test_throws ErrorException subscribe!(NotImplementedSubscribable(), actor)
        @test_throws ErrorException subscribe!(ExplicitlyDefinedSubscribable(), actor)

        @test subscribe!(ImplementedSubscribable(), actor) === Rx.VoidTeardown()
    end

end

end
