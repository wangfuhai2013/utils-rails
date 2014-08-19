module Utils
  module ViewHelper

    #输出布尔值标签
  	def bool_label(val)
      output = "<span class=\"label " + (val ? 'label-success' : 'label-default') +
              "\">" + (val ? '是' : '否')  +"</span>"
      output.html_safe
    end

    #输出预览图
    def thumbnail(file,width=150,use_thumb=true)
      output = '暂无图片'
      if file
        if use_thumb
          thumb_file = Utils::FileUtil.get_thumb_file(file) 
          full_name = Rails.root.join("public",thumb_file.to_s) 
          file = thumb_file if File.file?(full_name)
        end
        output = "<div class=\"img-thumbnail\">" + image_tag("/"+file,:width=>width) +"</div>"
      end
      
      output.html_safe
    end

    #字符串截取
    def str_trim(str,length,postfix='...')
		  str[0,length]+(str.length > length ? postfix : "") if str
	  end

    #分页显示标签
    def info_paginate(collection, options = {})
      pre_page = collection.current_page - 1
      next_page = collection.current_page + 1
      html = ""
      html += "<div id=\"" + options[:container] = "\">" unless options[:container].nil? 

      html += "<span>共<span>" + collection.total_entries.to_s + "</span>条记录<span>" +
              collection.total_pages.to_s + "</span>页</span>" if options[:show_total]

      html += "<span><a id=\"first\" href=\"" + url_for(params.merge(:page=> "1")) + 
               "\">第一页</a></span>" if options[:full_link] && collection.current_page > 1

      if pre_page > 0 
        html += "<span><a id=\"prev\" href=\"" + url_for(params.merge(:page=> pre_page)) + "\"" 
        html += " class=\"" + options[:class] + "\"" unless options[:class].nil?
        html += ">上一页</a></span>"
      end

      html += "<span>当前第<span>" + collection.current_page.to_s + "</span>页</span>" if options[:full_link]

      if next_page <= collection.total_pages
        html += "<span><a id=\"next\" href=\"" + url_for(params.merge(:page=> next_page)) + "\"" 
        html += " class=\"" + options[:class] + "\"" unless options[:class].nil?
        html += ">下一页</a></span>"
      end

      html += "<span><a id=\"last\" href=\"" + url_for(params.merge(:page=> collection.total_pages)) + 
               "\">最后一页</a></span>" if options[:full_link] && collection.current_page < collection.total_pages
      html += "</div>" unless options[:container].nil? 
      html.html_safe
    end

  end
end