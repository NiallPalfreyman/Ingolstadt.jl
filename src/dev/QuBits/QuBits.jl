#========================================================================================#
"""
	QuBits

Module QuBits: A package for experimenting with quantum computation.

Author: Niall Palfreyman, 03/05/22
"""
module QuBits

# Externally available names:
export Tensor, ⊗, kron, ⊚, kpow, isclose
export State, qubit, ampl, phase, prob, maxprob, nbits, off, on, pure, bitvec, density, ON, OFF
export Operator, ishermitian, isunitary, paulix, pauliy, pauliz, PauliX, PauliY, PauliZ
export string, call

# Imports:
import Base: kron, *

using LinearAlgebra

#========================================================================================#
# Tensor definitions:
#-----------------------------------------------------------------------------------------
"""
	Tensor

Tensor is our term for AbstractArray.
"""
Tensor = AbstractArray

#-----------------------------------------------------------------------------------------
"""
	Kronecker product ⊗

Define ⊗ as an infix operator for the Kronecker product of two Tensors
"""
⊗ = kron

#-----------------------------------------------------------------------------------------
# Tensor methods:

#-----------------------------------------------------------------------------------------
"""
	kpow( t::Tensor, n::Int)

Kronecker the Tensor t n times with itself.
"""
function kpow( t::Tensor, n::Int)
	if n==0
		# Base case:
		return 1.0
	end
	
	# Build Kronecker product:
	tn = t
	for _ in 1:(n-1)
		tn = tn ⊗ t
	end
	tn
end
# Use circled ring as operator for kpow:
⊚ = kpow

#-----------------------------------------------------------------------------------------
"""
	isclose( t::Union{Tensor,Number}, u::Union{Tensor,Number}, atol::Float64=1e-6)

Check whether all elements of the Tensor t are close to those of the Tensor u.
"""
function isclose( t::Union{Tensor,Number}, u::Union{Tensor,Number}, atol::Float64=1e-6)
	all(abs.(t.-u) .< atol)
end

#========================================================================================#
# State definitions:
#-----------------------------------------------------------------------------------------
"""
	State

A State is a collection of one or more qubits: a wrapper for Vector{Complex}.
"""
struct State <: Tensor{Complex,1}
	amp::Vector{Complex}								# The State amplitudes

	function State(amp::Vector)
		if isclose(amp,0.0)
			error("State vectors must be non-zero")
		end
		new(amp/norm(amp))
	end
end

Vectuple = Union{AbstractVector,Tuple}					# Useful for indexing States

#-----------------------------------------------------------------------------------------
# Delegated State methods:
Base.length(s::State) = length(s.amp)
Base.size(s::State) = size(s.amp)
Base.getindex(s::State,i::Integer) = getindex(s.amp,i)

#-----------------------------------------------------------------------------------------
# State constructors:
#-----------------------------------------------------------------------------------------
"""
	pure( d::Int=1, i::Int=1)

Construct an n-qubit State pure in the i-th amplitude.
"""
function pure( d::Int=1, i::Int=1)
	if d < 0
		error("Rank must be at least 1")
	end

	amp = zeros(Float64,1<<d)
	amp[i] = 1.0
	State(amp)
end

#-----------------------------------------------------------------------------------------
"""
	off( d::Int=1)

Construct the pure d-dimensional OFF state |000...0>
"""
function off( d::Int=1)
	pure( d, 1)
end

#-----------------------------------------------------------------------------------------
"""
	on( d::Int=1)

Construct the pure d-dimensional ON state |111...1>
"""
function on( d::Int=1)
	pure( d, 1<<d)
end

#-----------------------------------------------------------------------------------------
"""
	bitstring( bits)

Construct a state from the given bits.
"""
function bitvec( bits::Vectuple)
	bv = BitVector(bits)
	pure( length(bv), bits2dec(bv)+1)
end

bitvec( bits...) = bitvec(bits)

#-----------------------------------------------------------------------------------------
"""
	rand( n::Int)

Construct a random combination of n |0> and |1> states.
"""
function rand( n::Int)
	bitvec(Main.rand(Bool,n))
end

#-----------------------------------------------------------------------------------------
"""
	qubit( alpha::Complex, beta::Complex)

Construct a single qubit State from the given amplitudes.
"""
function qubit( alpha::Number, beta=nothing)
	if beta===nothing
		beta = sqrt(1.0 - alpha'*alpha)
	end

	State([alpha,beta])
end

function qubit(; alpha=nothing, beta=nothing)
	if alpha === beta === nothing
		# Neither amplitude is given:
		error("alpha, beta or both are required.")
	end

	if alpha === nothing
		# alpha not given:
		alpha = sqrt(1.0 - beta'*beta)
	end

	qubit(alpha,beta)
end

#-----------------------------------------------------------------------------------------
# State methods:
#-----------------------------------------------------------------------------------------
"""
	kron( op1::Operator, op2::Operator)

Kronecker product of two States is itself a State.
"""
kron( s1::State, s2::State) = State(kron(s1.amp,s2.amp))

#-----------------------------------------------------------------------------------------
"""
	getindex( s::State, bits::Vectuple)

Return the amplitude for qubit indexed by bits. Note: since binary values start from 0, we must
add 1 to the decimal conversion of bits.
"""
function Base.getindex( s::State, bits::Vectuple)
	s[bits2dec(BitVector(bits))+1]
end

"""
	getindex( s::State, bits...)

Return the amplitude specified by the given bit values.
"""
Base.getindex( s::State, bits...) = s[bits]

#-----------------------------------------------------------------------------------------
"""
	phase( s::State, bits::Vectuple)

Return the phase of the amplitude of the qubit indexed by bits.
"""
function phase( s::State, bits::Vectuple)
	angle(s[bits])
end

phase( s::State, i::Int) = angle(s[i])
phase( s::State, bits...) = phase(s,bits)

#-----------------------------------------------------------------------------------------
"""
	prob( s::State, bits::Vectuple)

Return probability for qubit indexed by bits.
"""
function prob( s::State, bits::Vectuple)
	amp = s[bits]							# Retrieve own amplitude
	real(conj(amp)*amp)						# Calculate its squared norm
end

prob( s::State, bits...) = prob(s,bits)

function prob( s::State, i::Int)
	amp = s[i]								# Retrieve own amplitude
	real(amp'*amp)							# Calculate its squared norm
end

#-----------------------------------------------------------------------------------------
"""
	normalise( s::State)

Normalise the state s (but throw an error if it's a zero state).
"""
function normalise(s::State)
	n = norm(s)
	if isclose(n,0.0)
		error("Attempted to normalise zero-probability state.")
	end
	s /= n
end

#-----------------------------------------------------------------------------------------
"""
	nbits( stt::State)

Return number of qubits in this state.
"""
function nbits( s::State)
	Int(log2(length(s)))
end

#-----------------------------------------------------------------------------------------
"""
	maxprob( stt::State)

Return tuple (bitindex,prob) of highest probability qubit in this State.
"""
function maxprob( s::State)
	mxindex, mxprob = -1, 0.0
	for i in 1:length(s)
		thisprob = prob(s,i)
		if thisprob > mxprob
			mxindex, mxprob = i, thisprob
		end
	end

	(mxindex, mxprob)
end

#-----------------------------------------------------------------------------------------
"""
	density( s::State)

Construct the density matrix of the state s.
"""
function density( s::State)
	s.amp * s.amp'
end

#-----------------------------------------------------------------------------------------
"""
	string( s::State)

Convert the State s to a String.
"""
function Base.string( s::State)
	str = "State{" * string(nbits(s)) * "}["
	for i in 1:length(s)-1
		str = str * "$(round(s[i],digits=4)), "
	end
	str = str * "$(round(s[end],digits=4))]"
end

Base.String( s::State) = string(s)

#-----------------------------------------------------------------------------------------
"""
	Base.show( io::IO, s::State)

Display the given State.
"""
function Base.show( io::IO, s::State)
	print( io, string(s))
end

#-----------------------------------------------------------------------------------------
"""
	Base.show( io::IO, ::MIME"text/plain", s::State)

Display the given State in verbose form.
"""
function Base.show( io::IO, ::MIME"text/plain", s::State)
	len = length(s)
	nb = nbits(s)
	bv = bitsvec(nb)
	println( io, nb, "-bit, ", len, "-amplitude State:")
	for bits in bv
		ampl = s[bits]
		println( io, " ",
			bits2str(bits), " : ", rpad(round(ampl,digits=4),18),
			": prob=", rpad(round(abs(ampl'*ampl),digits=4),7),
			": phase=", round(angle(ampl),digits=4)
		)
	end
end

#-----------------------------------------------------------------------------------------
# State constants:
#-----------------------------------------------------------------------------------------
"""
	OFF = off(1)

The off qubit.
"""
const OFF = off(1)

#-----------------------------------------------------------------------------------------
"""
	ON = on(1)

The on qubit.
"""
const ON = on(1)

#========================================================================================#
# Operator definitions:
#-----------------------------------------------------------------------------------------
"""
	Operator

An Operator is ???
"""
struct Operator <: Tensor{Complex,2}
	matrix::Matrix{Complex}								# The matrix operator

	function Operator(matrix::Matrix)
		if isclose(matrix,0.0)
			error("Operators must be non-zero")
		end
		new(matrix)
	end
end

#-----------------------------------------------------------------------------------------
# Delegated Operator methods:
Base.length(op::Operator) = length(op.matrix)
Base.size(op::Operator) = size(op.matrix)
Base.getindex(op::Operator,i::Integer,j::Integer) = getindex(op.matrix,i,j)

#-----------------------------------------------------------------------------------------
# Operator constructors:
#-----------------------------------------------------------------------------------------
"""
	identity( d::Int)

Construct d-dimensional identity Operator.
"""
function identity( d::Int=1)
	Operator([1 0;0 1] ⊚ d)
end

#-----------------------------------------------------------------------------------------
"""
	paulix( d::Int=1)

Construct d-dimensional Pauli-x Operator.
"""
function paulix( d::Int=1)
	Operator([0 1;1 0] ⊚ d)
end

#-----------------------------------------------------------------------------------------
"""
	pauliy( d::Int=1)

Construct d-dimensional Pauli-y Operator.
"""
function pauliy( d::Int=1)
	Operator([0 -im;im 0] ⊚ d)
end

#-----------------------------------------------------------------------------------------
"""
	pauliz( d::Int=1)

Construct d-dimensional Pauli-z Operator.
"""
function pauliz( d::Int=1)
	Operator([1 0;0 -1] ⊚ d)
end

#-----------------------------------------------------------------------------------------
# Operator methods:
#-----------------------------------------------------------------------------------------
"""
	kron( op1::Operator, op2::Operator)

Kronecker product of two Operators is itself an Operator.
"""
kron( op1::Operator, op2::Operator) = Operator( kron(op1.matrix,op2.matrix))

#-----------------------------------------------------------------------------------------
"""
	*( op1::Operator, op2::Operator)

Inner product of two Operators is itself an Operator.
"""
*( op1::Operator, op2::Operator) = Operator( *(op1.matrix,op2.matrix))

#-----------------------------------------------------------------------------------------
"""
	*( op::Operator, s::State)

Inner product of an Operator with a state is a transformed State.
"""
*( op::Operator, s::State) = State( *(op.matrix,s.amp))

#-----------------------------------------------------------------------------------------
"""
	call( op::Operator, s::State, idx::Int=1)

Apply the Operator op to the State s at the idx-th bit.
"""
function (op::Operator)( s::State, idx::Int=1)
	nbitsop = nbits(op)

	if idx > 1
		op = identity(idx-1) ⊗ op
	end

	remainingdims = nbits(s) - idx - nbitsop + 1
	if remainingdims > 0
		op = op ⊗ identity(remainingdims)
	end
	
	op * s
end

#-----------------------------------------------------------------------------------------
"""
	call( op1::Operator, op2::Operator)

Compose the Operator op1 followed by the Operator op2. Note the reversed order of multiplication!!
"""
function (op1::Operator)(op2::Operator, idx::Int=1)
	nbits2 = nbits(op2)

	if idx > 1
		op2 = identity(idx-1) ⊗ op2
	end

	if nbits(op1) > nbits(op2)
		op2 = op2 ⊗ identity(nbits(op1) - idx - nbits2 + 1)
	end
	
	op2 * op1
end

#-----------------------------------------------------------------------------------------
"""
	nbits( op::Operator)

Return number of qubits in this state.
"""
function nbits( op::Operator)
	Int(log2(size(op.matrix,1)))
end

#-----------------------------------------------------------------------------------------
"""
	ishermitian( op::Operator)

Check whether the Operator op is hermitian.
"""
function ishermitian( op::Operator)
	isclose(op,op')
end

#-----------------------------------------------------------------------------------------
"""
	isunitary( op::Operator)

Check whether the Operator op is unitary.
"""
function isunitary( op::Operator)
	m = op.matrix
	isclose(m*m',Matrix(I,size(m)))
end

#-----------------------------------------------------------------------------------------
"""
	string( op::Operator)

Convert the Operator op to a String.
"""
function Base.string( op::Operator)
	string( "Operator: ", op.matrix)
end

Base.String( op::Operator) = string(op)

#-----------------------------------------------------------------------------------------
"""
	Base.show( io::IO, op::Operator)

Display the given Operator op.
"""
function Base.show( io::IO, op::Operator)
	print( io, string(op))
end

#-----------------------------------------------------------------------------------------
"""
	Base.show( io::IO, ::MIME"text/plain", op::Operator)

Display the Operator op in verbose form.
"""
function Base.show( io::IO, ::MIME"text/plain", op::Operator)
	println( io, "Operator:")
	for i in 1:size(op.matrix,1)
		print( io, " ")
		for j in 1:size(op.matrix,2)
			print( io, rpad(round(op.matrix[i,j],digits=4),20))
		end
		println()
	end
end

#-----------------------------------------------------------------------------------------
# Operator constants:
#-----------------------------------------------------------------------------------------
"""
	PauliX = paulix(1)

The 1-d Pauli X-gate.
"""
const PauliX = paulix()

#-----------------------------------------------------------------------------------------
"""
	PauliY = pauliy(1)

The 1-d Pauli Y-gate.
"""
const PauliY = pauliy()

#-----------------------------------------------------------------------------------------
"""
	PauliZ = pauliz(1)

The 1-d Pauli Z-gate.
"""
const PauliZ = pauliz()

#========================================================================================#
# Helper methods:
#-----------------------------------------------------------------------------------------
"""
	bits2str( bits::Vectuple)

Format bit vector as string
"""
function bits2str( bits::Vectuple)
	"|" * string([+s for s in bits]...) * ">=|" * string(bits2dec(bits)) * ">"
end

bits2str(bits...) = bits2str(bits)

#-----------------------------------------------------------------------------------------
"""
	bits2dec( bits::BitVector)

Compute decimal representation of a BitVector.
"""
function bits2dec( bits::BitVector)
	s = 0; v = 1
	for i in view(bits,length(bits):-1:1)
		s += v*i
		v <<= 1
	end 
	s
end

#-----------------------------------------------------------------------------------------
"""
	dec2bits( dec::Int, nbits::Int)

Compute a hi2lo nbit binary representation of a decimal value.
"""
function dec2bits( dec::Int, nbits::Int)
	BitVector(reverse( digits(dec, base=2, pad=nbits)))
end

#-----------------------------------------------------------------------------------------
"""
	bitsvec( nbits::Int)

Construct a list of all binary numbers containing nbits in numerical order.
"""
function bitsvec( nbits::Int)
    [dec2bits(i,nbits) for i in 0:1<<nbits-1]
end

#-----------------------------------------------------------------------------------------
function demo()
	op1 = paulix()
	op2 = pauliy()
	(:($op1($op2)),op1(op2))
end

end		# ... of module QuBits