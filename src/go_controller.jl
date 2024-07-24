
mutable struct GoControllerIOStream <: ExternalDeviceIOStream
    handle::HANDLE
    connected_stages::Vector{Bool}
end

function search(::Type{GoControllerName})
    num_devices = CreateDeviceInfoList()
    GetDeviceInformationList(num_devices)
end

function open(controller_name::GoControllerName)
    # connect device
    handle = SelectDevice(controller_name)
    connected_stages = try
        InitializeDevice(handle)
        # detect available stages
        command = "RS xyz"
        result = SendReceive(handle, command)
        connected_stages = zeros(Bool, 3)
        for (idx, stage_id) = enumerate('x':'z')
            stage_id_position = findfirst(stage_id, result)
            if !isnothing(stage_id_position) && result[stage_id_position+1] != '6'
                connected_stages[idx] = true
            end
        end
        if !any(connected_stages)
            close(stage)
            error("No available stages on the device")
        end
        connected_stages
    catch e
        UnselectDevice(handle)
        throw(e)
    end
    GoControllerIOStream(handle, connected_stages)
end

function close(controller::GoControllerIOStream)
    # disconnect device
    UnselectDevice(controller.handle)
    controller.connected_stages .= false
    controller
end

function isopen(controller::GoControllerIOStream)
    any(controller.connected_stages)
end

function send(controller::GoControllerIOStream, command::String)
    Send(controller.handle, command)
end

function send_receive(controller::GoControllerIOStream, command::String)
    SendReceive(controller.handle, command)
end