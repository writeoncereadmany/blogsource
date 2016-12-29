def extract_smell(content) 
  content.gsub(/<span class="s">"!!(?<smell>[^!]*)!!"<\/span>/) do |match|
    smell = $1
    if smell == 'end' then '</span>' else "<span class=#{smell}>" end
  end
end

Jekyll::Hooks.register :posts, :post_render do |post|
   post.output = extract_smell(post.output)
   post.data["excerpt"].output = extract_smell(post.data["excerpt"].output)
end
