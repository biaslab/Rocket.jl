export LazyObservable, lazy, set!

import Base: |>
import Base: show

struct LazyObservable{D} <: Subscribable{D}
    inner :: SingleSubject{Any}

    LazyObservable{D}() where D = new(SingleSubject{Any}())
end

set!(lazy::LazyObservable{D}, observable::S) where D where S = on_lazy_set!(lazy, as_subscribable(S), observable)

on_lazy_set!(lazy::LazyObservable{D},  ::InvalidSubscribable,   observable) where D           = throw(InvalidSubscribableTraitUsageError(observable))
on_lazy_set!(lazy::LazyObservable{D1}, ::ValidSubscribable{D2}, observable) where D1 where D2 = next!(lazy.inner, observable)

function on_subscribe!(observable::LazyObservable{D}, actor::A) where { A <: AbstractActor{D} } where D
    return subscribe!(observable.inner |> switchMap(D), actor)
end

lazy(T = Any) = LazyObservable{T}()

Base.show(io::IO, observable::LazyObservable{D}) where D = print(io, "LazyObservable($D)")
