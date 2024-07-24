# PrecibeoStages.jl

PrecibeoStages is a Julia interface for Precibeo Go controller.  

## Installation

It additionally requires `ExternalDeviceIOs`.Therefore, to install this package, you should type

```Julia REPL
julia> ]add https://github.com/ehgus/ExternalDeviceIOs.jl https://github.com/ehgus/PrecibeoStages.jl
```


## Example

```Julia
using PrecibeoStages

controller_list = search(GoControllerName)
controller = controller_list[1]
open(controller) do io
    @show send_receive(io,"RS xyz")
end
```