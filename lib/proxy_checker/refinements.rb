module CoreExtensions
  refine Object do
    def blank?
      nil? || empty?
    end
  end
  refine String do
    def blank?
      super || strip.empty?
    end
  end
  refine Hash do
    def except!(*candidates)
      candidates.each { |candidate| delete(candidate) }
      self
    end

    def except(*candidates)
      dup.except!(candidates)
    end
  end
end
