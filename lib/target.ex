defmodule Flect.Target do
    @moduledoc """
    Provides various target configuration information.
    """

    @doc """
    Returns the installation prefix (`FLECT_PREFIX`).
    """
    @spec get_prefix() :: String.t()
    def :get_prefix, [], [] do
        System.get_env("FLECT_PREFIX")
    end

    @doc """
    Returns the binary path (`FLECT_BIN_DIR`).
    """
    @spec get_bin_dir() :: String.t()
    def :get_bin_dir, [], [] do
        System.get_env("FLECT_BIN_DIR")
    end

    @doc """
    Returns the library path (`FLECT_LIB_DIR`).
    """
    @spec get_lib_dir() :: String.t()
    def :get_lib_dir, [], [] do
        System.get_env("FLECT_LIB_DIR")
    end

    @doc """
    Returns the static library path (`FLECT_ST_LIB_DIR`).
    """
    @spec get_st_lib_dir() :: String.t()
    def :get_st_lib_dir, [], [] do
        System.get_env("FLECT_ST_LIB_DIR")
    end

    @doc """
    Returns the shared library path (`FLECT_SH_LIB_DIR`).
    """
    @spec get_sh_lib_dir() :: String.t()
    def :get_sh_lib_dir, [], [] do
        System.get_env("FLECT_SH_LIB_DIR")
    end

    @doc """
    Returns the path to the backing C99 compiler (`FLECT_CC`).
    """
    @spec get_cc() :: String.t()
    def :get_cc, [], [] do
        System.get_env("FLECT_CC")
    end

    @doc """
    Returns the type of the backing C99 compiler (`FLECT_CC_TYPE`).
    """
    @spec get_cc_type() :: String.t()
    def :get_cc_type, [], [] do
        System.get_env("FLECT_CC_TYPE")
    end

    @doc """
    Returns the arguments to pass to the backing C99 compiler (`FLECT_CC_ARGS`).
    """
    @spec get_cc_args() :: String.t()
    def :get_cc_args, [], [] do
        System.get_env("FLECT_CC_ARGS")
    end

    @doc """
    Returns the backing object code linker (`FLECT_LD`).
    """
    @spec get_ld() :: String.t()
    def :get_ld, [], [] do
        System.get_env("FLECT_LD")
    end

    @doc """
    Returns the type of the backing object code linker (`FLECT_LD_TYPE`).
    """
    @spec get_ld_type() :: String.t()
    def :get_ld_type, [], [] do
        System.get_env("FLECT_LD_TYPE")
    end

    @doc """
    Returns the arguments to pass to the backing object code linker (`FLECT_LD_ARGS`).
    """
    @spec get_ld_args() :: String.t()
    def :get_ld_args, [], [] do
        System.get_env("FLECT_LD_ARGS")
    end

    @doc """
    Returns the target operating system (`FLECT_OS`).
    """
    @spec get_os() :: String.t()
    def :get_os, [], [] do
        System.get_env("FLECT_OS")
    end

    @doc """
    Returns the target architecture (`FLECT_ARCH`).
    """
    @spec get_arch() :: String.t()
    def :get_arch, [], [] do
        System.get_env("FLECT_ARCH")
    end

    @doc """
    Returns the target application binary interface (`FLECT_ABI`).
    """
    @spec get_abi() :: String.t()
    def :get_abi, [], [] do
        System.get_env("FLECT_ABI")
    end

    @doc """
    Returns the target endianness (`FLECT_ENDIAN`).
    """
    @spec get_endian() :: String.t()
    def :get_endian, [], [] do
        System.get_env("FLECT_ENDIAN")
    end

    @doc """
    Returns a value indicating whether this is a cross compiler (`FLECT_CROSS`).
    """
    @spec get_cross() :: String.t()
    def :get_cross, [], [] do
        System.get_env("FLECT_CROSS")
    end
end
