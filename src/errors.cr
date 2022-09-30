module Eyrie
  class Error < Exception
    enum Status
      INVALID_NAME
      INVALID_VERSION
      INVALID_SUPPORTS
      CANNOT_SUPPORT
      NO_FILES
      PULL_GIT_FAILED
      PULL_LOCAL_FAILED
    end

    getter status : Status

    def initialize(@status : Status)
      super @status.to_s
    end

    def initialize(ex : Exception, @status : Status)
      super @status.to_s, cause: ex
    end

    def format : Array(String)
      msg = case @status
            in Status::INVALID_NAME
              ["Module name is invalid", "Module name can only contain letters, numbers, dashes and underscores"]
            in Status::INVALID_VERSION
              ["Invalid version format", "Module versions must be in the major.minor.patch format"]
            in Status::INVALID_SUPPORTS
              ["Invalid supported version", "Supported version must be in the major.minor.patch format"]
            in Status::CANNOT_SUPPORT
              ["This module cannot support the current panel version"]
            in Status::NO_FILES
              ["No files were specified to install with the module", "Cannot guess which files to install"]
            in Status::PULL_GIT_FAILED
              ["Could not pull module files from git repository"]
            in Status::PULL_LOCAL_FAILED
              ["Could not pull module files from local file system"]
            end

      if ex = cause
        msg << ex.message.not_nil!
      end

      msg
    end
  end

  class SystemExit < Exception
  end
end
