module CellDataTests

using Gridap
using GridapDistributed
using PartitionedArrays
using Test

function main(distribute,parts)
  @assert length(parts) == 2

  ranks = distribute(LinearIndices((prod(parts),)))

  output = mkpath(joinpath(@__DIR__,"output"))

  domain = (0,4,0,4)
  cells = (4,4)
  model = CartesianDiscreteModel(ranks,parts,domain,cells)
  Ω = Triangulation(model)
  Γ = Boundary(model,tags="boundary")

  f = CellField(x->x[1]+x[2],Ω)
  g = CellField(4.5,Γ)
  v = CellField(x->x,Ω)

  u(x) = sum(x)
  writevtk(Ω,joinpath(output,"Ω"),cellfields=["f"=>f,"u"=>u])
  writevtk(Γ,joinpath(output,"Γ"),cellfields=["f"=>f,"g"=>g,"u"=>u])

  createpvd(ranks,joinpath(output,"Ω_pvd")) do pvd
    pvd[0.1] = createvtk(Ω,joinpath(output,"Ω_1"),cellfields=["f"=>f])
    pvd[0.2] = createvtk(Ω,joinpath(output,"Ω_2"),cellfields=["f"=>f])
  end
  @test isfile(joinpath(output,"Ω_pvd")*".pvd")

  x_Γ = get_cell_points(Γ)
  @test isa(f(x_Γ),AbstractArray)

  h = 4*f
  h = f*g
  h = (v->3*v)∘(f)
  h = ∇(f)
  h = ∇⋅v
  h = ∇×v

  dΩ = Measure(Ω,1)
  dΓ = Measure(Γ,1)

  @test sum( ∫(1)dΩ ) ≈ 16.0
  @test sum( ∫(1)dΓ ) ≈ 16.0
  @test sum( ∫(g)dΓ ) ≈ 4.5*16.0

  x_Γ = get_cell_points(dΓ)
  @test isa(f(x_Γ),AbstractArray)

  _my_op(u,v,h) = u + v - h
  u1 = CellField(0.0,Ω)
  u2 = CellField(1.0,Ω)
  u3 = CellField(2.0,Ω)
  u = _my_op∘(u1,u2,u3)

  # Point δ
  δ=DiracDelta{0}(model;tags=2)
  @test sum(δ(f)) ≈ 4.0
  @test sum(δ(3.0)) ≈ 3.0
  @test sum(δ(x->2*x)) ≈ VectorValue(8.0,0.0)
  
  # Line δ
  degree = 2
  δ = DiracDelta{1}(model,degree,tags=5)
  @test sum(δ(f)) ≈ 8.0
  @test sum(δ(3.0)) ≈ 12.0
  @test sum(δ(x->2*x)) ≈ VectorValue(16.0,0.0)

end

end # module
