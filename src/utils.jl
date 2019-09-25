export projector, print_blocktree
using InteractiveUtils

"""
    projector(x)

Return projector on `0` or projector on `1`.
"""
projector(x) = code==0 ? mat(P0) : mat(P1)

"""
    print_subtypetree(::Type[, level=1, indent=4])

Print subtype tree, `level` specify the depth of the tree.
"""
function print_subtypetree(t::Type, level=1, indent=4)
    level == 1 && println(t)
    for s in subtypes(t)
        println(join(fill(" ", level * indent)) * string(s))
        print_subtypetree(s, level+1, indent)
    end
end
