"""
    DirectedTree{S<:Real}

A tree graph with a single sink node.
"""
Base.@kwdef mutable struct DirectedTree{S<:Real} <: AbstractDirectedAcyclicGraph{S}
    "List of nodes"
    nodes::Vector{Node}                       = Node[]
    "List of index of variables"
    variables::Vector{Int}                    = Int[]
    "List of variable types"
    variable_types::Vector{VariableType}      = VariableType[]
    "List of constant values"
    constant_values::Vector{S}                = S[]
    "Number of nodes"
    node_count::Int                           = 0
    "Number of variables"
    variable_count::Int                       = 0
    "Number of constants"
    constant_count::Int                       = 0
    ""
    sparsity::Vector{Int}                     = Int[]
    ""
    rev_sparsity::Vector{Int}                 = Int[]
    dependent_variable_count::Int             = 0
    dep_subexpr_count::Int        = 0
    dependent_subexpressions::Vector{Int}     = Int[]
    linearity::Linearity                      = LIN_CONSTANT
    user_operators::JuMPOpReg                 = JuMPOpReg()
end
const DAT = DirectedTree

# graph property access functions
@inbounds _sparsity(g::DAT)          = g.sparsity
@inbounds _rev_sparsity(g::DAT )     = g.rev_sparsity
@inbounds _nodes(g::DAT)             = g.nodes
@inbounds _variables(g::DAT)         = g.variables
@inbounds _variable_types(g::DAT)    = g.variable_types
@inbounds _constant_values(g::DAT)   = g.constant_values
@inbounds _dep_subexpr_count(g::DAT) = g.dep_subexpr_count

# user-define function access
@inline function _user_univariate_operator(g::DAT, i)
    @inbounds g.user_operators.univariate_operator_f[i]
end
@inline function _user_multivariate_operator(g::DAT, i)
    @inbounds g.user_operators.multivariate_operator_evaluator[i]
end

function fprop!(::Type{T}, g::DAT, b::AbstractCache) where {T<:AbstractCacheAttribute}
    f_init!(T, g, b)
    for k = _node_count(g):-1:1
        nt = _node_class(g, k)
        if nt == EXPRESSION
            fprop!(T, Expression, g, b, k)
        elseif nt == VARIABLE
            fprop!(T, Variable, g, b, k)
        elseif nt == SUBEXPRESSION
            fprop!(T, Subexpression, g, b, k)
        end
    end
    return
end

function rprop!(::Type{T}, g::DAT, b::AbstractCache) where {T<:AbstractCacheAttribute}
    r_init!(T, g, b)
    for k = 1:_node_count(g)
        nt = _node_class(g, k)
        if nt == EXPRESSION
            rprop!(T, Expression, g, b, k)
        elseif nt == VARIABLE
            rprop!(T, Variable, g, b, k)
        end
    end
    return
end

# TODO Fix constructor...
function DirectedTree{S}(d, sub_sparsity::Dict{Int,Vector{Int}}, subexpr_linearity) where S<:Real

    nd = copy(d.nd)
    adj = copy(d.adj)
    const_values = copy(d.const_values)

    sparsity, dependent_subexpressions = _compute_sparsity(d, sub_sparsity)

    rev_sparsity_len = sparsity[end]
    rev_sparsity = zeros(Int, rev_sparsity_len)

    nodes = _convert_node_list(d.nd)
    n = length(rev_sparsity)
    variable_types = fill(VT_CONT, n)
    lin = linearity(nd, adj, subexpr_linearity)
    DirectedTree{S}(nodes = nodes,
                    variables = rev_sparsity,
                    variable_types = variable_types,
                    constant_values = const_values,
                    node_count = length(nodes),
                    variable_count = n,
                    constant_count = length(const_values),
                    sparsity = sparsity,
                    rev_sparsity = rev_sparsity,
                    dependent_variable_count = n,
                    dep_subexpr_count = length(dependent_subexpressions),
                    dependent_subexpressions = copy(dependent_subexpressions),
                    linearity = lin[1]
                    )
end
