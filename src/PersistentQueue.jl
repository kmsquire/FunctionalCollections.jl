immutable PersistentQueue{T}
    in::AbstractList{T}
    out::AbstractList{T}
    length::Int

    PersistentQueue(in::AbstractList{T}, out::AbstractList{T}, length::Int) =
        new(in, out, length)

    PersistentQueue() = new(EmptyList{T}(), EmptyList{T}(), 0)
end

PersistentQueue{T}(v::Vector{T}) =
    PersistentQueue{T}(EmptyList{T}(), reverse(PersistentList(v)), length(v))

queue = PersistentQueue

Base.length(q::PersistentQueue) = q.length
Base.isempty(q::PersistentQueue) = is(q.length, 0)

peek(q::PersistentQueue) = isempty(q.out) ? head(reverse(q.in)) : head(q.out)

pop{T}(q::PersistentQueue{T}) =
    if isempty(q.out)
        PersistentQueue{T}(EmptyList{T}(), tail(reverse(q.in)), length(q) - 1)
    else
        PersistentQueue{T}(q.in, tail(q.out), length(q) - 1)
    end

enq{T}(q::PersistentQueue{T}, val) =
    if isempty(q.in) && isempty(q.out)
        PersistentQueue{T}(q.in, val..EmptyList{T}(), 1)
    else
        PersistentQueue{T}(val..q.in, q.out, length(q) + 1)
    end

Base.start(q::PersistentQueue) = (q.in, q.out)
Base.done{T}(::PersistentQueue{T}, state::(EmptyList{T}, EmptyList{T})) = true
Base.done(::PersistentQueue, state) = false

function Base.next{T}(::PersistentQueue{T}, state::(AbstractList{T},
                                                    PersistentList{T}))
    in, out = state
    (head(out), (in, tail(out)))
end
function Base.next{T}(q::PersistentQueue{T}, state::(PersistentList{T},
                                                     EmptyList{T}))
    in, out = state
    next(q, (EmptyList{T}(), reverse(in)))
end
