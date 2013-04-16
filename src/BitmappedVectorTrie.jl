# `shiftby` is equal to the number of bits required to represent index information
# for one level of the BitmappedTrie.
#
# Here, `shiftby` is 5, which means that the BitmappedTrie Arrays will be length 32.
const shiftby = 5
const trielen = 2^shiftby
const andval  = trielen - 1

abstract Trie

immutable BitmappedTrie <: Trie
    self::Array
    shift::Int
    length::Int
    maxlength::Int
end
BitmappedTrie() = BitmappedTrie(Any[], 0, 0, trielen)

Base.length(bt::Trie) = bt.length
Base.endof(bt::Trie) = bt.length

import Base.==
function ==(t1::Trie, t2::Trie)
    t1.length    == t2.length    &&
    t1.shift     == t2.shift     &&
    t1.maxlength == t2.maxlength &&
    t1.self      == t2.self
end

similar(bt::Trie) =
    typeof(bt)(Any[], bt.shift, 0, bt.maxlength)

promoted(bt::Trie) =
    typeof(bt)(Any[bt], bt.shift + shiftby, bt.length, bt.maxlength * trielen)

demoted(bt::Trie) =
    typeof(bt)(Any[], bt.shift - shiftby, 0, int(bt.maxlength / trielen))

withself(bt::Trie, self::Array) = withself(bt, self, 0)
withself(bt::Trie, self::Array, lenshift::Int) =
    typeof(bt)(self, bt.shift, length(bt) + lenshift, bt.maxlength)

# Copy elements from one Array to another, up to `n` elements.
#
function copy_to(from::Array, to::Array, n::Int)
    for i=1:n
        to[i] = from[i]
    end
    to
end

# Copies elements from one Array to another of size `len`.
#
copy_to_len{T}(from::Array{T}, len::Int) =
    copy_to(from, Array(T, len), min(len, length(from)))

function append(bt::BitmappedTrie, el)
    if bt.shift == 0
        if length(bt) < trielen
            newself = copy_to_len(bt.self, 1 + length(bt))
            newself[end] = el
            withself(bt, newself, 1)
        else
            append(promoted(bt), el)
        end
    else
        if length(bt) == 0
            withself(bt, Any[append(demoted(bt), el)], 1)
        elseif length(bt) < bt.maxlength
            if length(bt.self[end]) == bt.self[end].maxlength
                newself = copy_to_len(bt.self, 1 + length(bt.self))
                newself[end] = append(demoted(bt), el)
                withself(bt, newself, 1)
            else
                newself = bt.self[1:end]
                newself[end] = append(bt.self[end], el)
                withself(bt, newself, 1)
            end
        else
            append(promoted(bt), el)
        end
    end
end
push = append

function get(bt::Trie, i::Int)
    # Decrement i so that the bitwise math works out. It will be incremented
    # before indexing into Arrays.
    i -= 1
    if bt.shift == 0
        bt.self[(i & andval) + 1]
    else
        get(bt.self[((i >>> bt.shift) & andval) + 1], i + 1)
    end
end

function Base.getindex(bt::Trie, i::Int)
    i <= length(bt) || error(BoundsError())
    get(bt, i)
end

function update(bt::BitmappedTrie, i::Int, element)
    i -= 1
    if bt.shift == 0
        newself = bt.self[1:end]
        newself[(i & andval) + 1] = element
    else
        newself = bt.self[1:end]
        idx = ((i >>> bt.shift) & andval) + 1
        newself[idx] = update(newself[idx], i + 1, element)
    end
    BitmappedTrie(newself, bt.shift, bt.length, bt.maxlength)
end

peek(bt::BitmappedTrie) = bt[end]

# Pop is usually destructive, but that doesn't make sense for an immutable
# structure, so `pop` is defined to return a Trie without its last
# element. Use `peek` to access the last element.
#
function pop(bt::BitmappedTrie)
    if bt.shift == 0
        withself(bt, bt.self[1:end-1], -1)
    else
        newself = bt.self[1:end]
        newself[end] = pop(newself[end])
        withself(bt, newself, -1)
    end
end

type TransientBitmappedTrie <: Trie
    self::Array
    shift::Int
    length::Int
    maxlength::Int
    persistent::Bool
end
TransientBitmappedTrie(self::Array, shift::Int, length::Int, maxlength::Int) =
    TransientBitmappedTrie(self, shift, length, maxlength, false)
TransientBitmappedTrie() = TransientBitmappedTrie(Any[], 0, 0, trielen)

function persist!(tbt::TransientBitmappedTrie)
    tbt.persistent = true
    self = tbt.shift == 0 ? tbt.self : map(persist!, tbt.self)
    BitmappedTrie(self, tbt.shift, tbt.length, tbt.maxlength)
end

function promote!(tbt::TransientBitmappedTrie)
    tbt.self = Any[withself(tbt, tbt.self)]
    tbt.shift += shiftby
    tbt.maxlength *= trielen
    tbt
end

function Base.push!(tbt::TransientBitmappedTrie, el)
    tbt.persistent && error("Cannot mutate Transient after call to persist!")
    if tbt.shift == 0
        if length(tbt) < tbt.maxlength
            push!(tbt.self, el)
            tbt.length += 1
            tbt
        else
            push!(promote!(tbt), el)
        end
    else
        if length(tbt) == 0
            tbt.self = Any[push!(demoted(tbt), el)]
            tbt.length += 1
            tbt
        elseif length(tbt) < tbt.maxlength
            if length(tbt.self[end]) == tbt.self[end].maxlength
                push!(tbt.self, push!(demoted(tbt), el))
                tbt.length += 1
                tbt
            else
                push!(tbt.self[end], el)
                tbt.length += 1
                tbt
            end
        else
            push!(promote!(tbt), el)
        end
    end
end

function Base.setindex!(tbt::TransientBitmappedTrie, el, i::Real)
    i -= 1
    if tbt.shift == 0
        tbt.self[(i & andval) + 1] = el
    else
        idx = ((i >>> tbt.shift) & andval) + 1
        tbt.self[idx][i + 1] = el
    end
    el
end