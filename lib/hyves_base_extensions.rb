class String

  # This is a copy of ActionView::Helpers::TextHelper::auto_link_urls.
  # Instead of the default <a href ..> it creates a Hyves link: [url=http://blog.joopp.com]blog.joopp.com[/url]
  def auto_hyves_link_urls
    self.gsub(ActionView::Helpers::TextHelper::AUTO_LINK_RE) do
      all, a, b, c, d = $&, $1, $2, $3, $4
      if a =~ /\[url\=/i # don't replace URL's that are already linked
        all
      else
        text = b + c
        text = yield(text) if block_given?
        %(#{a}\[url=#{ (b == "www.") ? "http://www." : b }#{c}\]#{text}\[\/url\]#{d})
      end
    end
  end

end