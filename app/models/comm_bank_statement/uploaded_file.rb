# frozen_string_literal: true

module CommBankStatement
  # Minimal upload stand-in for AccountStatement.prepare_upload!
  class UploadedFile
    def initialize(path)
      @path = path
      @io = File.open(path, "rb")
    end

    def read(chunk_size = nil)
      @io.read(chunk_size)
    end

    def rewind
      @io.rewind
    end

    def size
      File.size(@path)
    end

    def original_filename
      File.basename(@path)
    end

    def content_type
      "application/pdf"
    end

    def close
      @io.close unless @io.closed?
    end
  end
end
