function library_path()
    default_dir = "C:/Program Files (x86)/PRECIBEO GO API Package"
    lib_path = @load_preference("shared library path", default_dir)

    if !isdir(lib_path)
        error("the library does not exists")
        lib_path = default_dir
    else
        R11_SDK_dll_path = joinpath(lib_path, "PrecibeoGoAPI.dll")
        if !isfile(R11_SDK_dll_path)
            error("PrecibeoGoAPI.dll should exist at the library path")
            lib_path = default_dir
        end
    end
    lib_path
end

function library_path!(lib_path; export_prefs::Bool = false)
    if isnothing(lib_path) || ismissing(lib_path)
        # supports `Preferences` sentinel values `nothing` and `missing`
    elseif !isa(lib_path,String)
        throw(ArgumentError("Invalid provider"))
    elseif !isdir(lib_path)
        throw(ArgumentError("the library does not exists"))
    else
        lib_path = abspath(lib_path)
        R11_SDK_dll_path = joinpath(lib_path, "PrecibeoGoAPI.dll")
        if !isfile(R11_SDK_dll_path)
            throw(ArgumentError("PrecibeoGoAPI.dll should exist at the library path"))
        end
    end
    set_preferences!(@__MODULE__, "shared library path" => lib_path;export_prefs, force = true)
    if !samefile(lib_path, shared_lib_path)
        # Re-fetch to get default values in the event that `nothing` or `missing` was passed in.
        lib_path = library_path()
        @info("The path of shared library is changed; restart Julia for this change to take effect", lib_path)
    end
end

const shared_lib_path = library_path()
const SDK_DLL = Ref{Ptr{Cvoid}}(0)
function __init__()
    precibeo_SDK_dll = dlopen(joinpath(shared_lib_path,"PrecibeoGoAPI.dll"))
    SDK_DLL[] = precibeo_SDK_dll
end

# typedef
const HANDLE = Ptr{Cvoid}
const DWORD = Culong
const LPDWORD = Ptr{DWORD}
const LPSTR = Ptr{UInt8} # single character
const LPCSTR = Ptr{UInt8} # string = null-terminated array
const BOOL = Cuchar
const SIZE_T = Cuint

# struct
@kwdef struct GoControllerName <: ExternalDeviceName
    flags::DWORD = DWORD(0)
    type::DWORD = DWORD(0)
    ID::DWORD = DWORD(0)
    locationID::DWORD = DWORD(0)
    serial_number::NTuple{16,UInt8} = ntuple(_->UInt8(0), 16)
    description::NTuple{64,UInt8} = ntuple(_->UInt8(0), 64)
    handle::HANDLE = HANDLE(0)
end

# enum
@enumx STATUS::Culong begin
    OK
    INVALID_HANDLE
    DEVICE_NOT_FOUND
    DEVICE_NOT_OPENED
    IO_ERROR
    INSUFFICIENT_RESOURCES
    INVALID_PARAMETER
    INVALID_BAUD_RATE
    DEVICE_NOT_OPENED_FOR_ERASE
    DEVICE_NOT_OPENED_FOR_WRITE
    FAILED_TO_WRITE_DEVICE
    EEPROM_READ_FAILED
    EEPROM_WRITE_FAILED
    EEPROM_ERASE_FAILED
    EEPROM_NOT_PRESENT
    EEPROM_NOT_PROGRAMMED
    INVALID_ARGS
    NOT_SUPPORTED
    OTHER_ERROR
    DEVICE_LIST_NOT_READY
end

# @enumx USB_DEVICE_TYPE begin
#     FULL_SPEED_USB_DEVICE = 0
#     HIGH_SPEED_USB_DEVICE = 2
# end

macro check_status(expr)
    (Meta.isexpr(expr,:ccall) && expr.args[1] === :ccall && expr.args[3] === :Cuint) || "invalid use of @rccheck"
    return quote
        status = $(esc(expr))
        if STATUS.T(status) != STATUS.OK
            txt = "failure status: $(String(status))"
            error(txt)
        end
        nothing
    end
end

# function GetUSBDeviceType(flag)
#     F = dlsym(SDK_DLL[], :Precibeo_GetUSBDeviceType)
#     ccall(F, USB_DEVICE_TYPE, (DWORD,), flag)
# end

# function IsPortOpen(flag)
# 
#     F = dlsym(SDK_DLL[], :Precibeo_IsPortOpen)
#     ccall(F, BOOL, (DWORD,), flag)
# end

# function IsPrecibeoDeviceOpenElsewhere(device_list_info_node)
#     F = dlsym(SDK_DLL[], :Precibeo_IsPrecibeoDeviceOpenElsewhere)
#     ccall(F, BOOL, (GoControllerName,), device_list_info_node)
# end

function CreateDeviceInfoList()
    num_devices = Ref(DWORD(0))
    F = dlsym(SDK_DLL[], :Precibeo_CreateDeviceInfoList)
    status = ccall(F, Culong, (LPDWORD,), num_devices)
    if STATUS.T(status) === STATUS.OK
        num_devices[]
    else
        0
    end
end

 function GetDeviceInformationList(num_devices)
    device_list =  Ref(ntuple(_->GoControllerName(), num_devices))
    F = dlsym(SDK_DLL[], :Precibeo_GetDeviceInformationList)
    status = ccall(F, Culong, (Ptr{GoControllerName},LPDWORD),device_list, Ref(num_devices))
    if STATUS.T(status) == STATUS.OK
        device_list[]
    else
        ()
    end
end

function InitializeDevice(handle)
    F = dlsym(SDK_DLL[], :Precibeo_InitializeDevice)
    @check_status ccall(F, Culong, (HANDLE,), handle)
end

function SelectDevice(device::GoControllerName)
    F = dlsym(SDK_DLL[], :Precibeo_SelectDevice)
    handle_ref = Ref{HANDLE}(0)
    @check_status ccall(F, Culong, (LPSTR, Ptr{HANDLE}), Ref(device.serial_number), handle_ref)
    handle_ref[]
end

function UnselectDevice(handle::HANDLE)
    F = dlsym(SDK_DLL[], :Precibeo_UnSelectDevice)
    @check_status ccall(F, Culong, (HANDLE,), handle)
end

function Send(handle::HANDLE, command::String)
    F = dlsym(SDK_DLL[], :Precibeo_Send)
    @check_status ccall(F, Culong, (HANDLE,LPCSTR), handle, Ref(Tuple(transcode(UInt8,command*"\r\n\0"))))
end

function SendReceive(handle::HANDLE, command::String)
    msg = Ref(ntuple(_->UInt8(0), 64))
    F = dlsym(SDK_DLL[], :Precibeo_SendReceive)
    @check_status ccall(F, Culong, (HANDLE,LPCSTR,LPSTR,SIZE_T), handle, Ref(Tuple(transcode(UInt8,command*"\r\n\0"))), msg, length(msg[]))
    strip(transcode(String, [msg[]...]),['\0','\r','\n'])
end