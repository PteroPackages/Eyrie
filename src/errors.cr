module Eyrie
  class Error < Exception
    enum Status
      INVALID_NAME
      INVALID_VERSION
      INVALID_SUPPORTS
      NO_FILES
    end

    getter status : Status

    def initialize(@status : Status)
      super @status.to_s
    end

    def format : Array(String)
      case @status
      in Status::INVALID_NAME
        ["module name is invalid", "module name can only contain letters, numbers, dashes and underscores"]
      in Status::INVALID_VERSION
        ["invalid version format", "module versions must be in the major.minor.patch format"]
      in Status::INVALID_SUPPORTS
        ["invalid supported version", "supported version must be in the major.minor.patch format"]
      in Status::NO_FILES
        ["no files were specified to install with the module", "cannot guess which files to install"]
      end
    end
  end
end
