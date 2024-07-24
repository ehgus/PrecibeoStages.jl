module PrecibeoStages

using ExternalDeviceIOs
using Preferences
using EnumX
using Libdl: dlopen, dlsym

import Base:
    open,
    close,
    isopen

export GoControllerName, search, send, send_receive

include("api.jl")
include("go_controller.jl")

end # module PrecibeoStages
