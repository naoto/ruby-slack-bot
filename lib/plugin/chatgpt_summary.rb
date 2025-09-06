# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'
require_relative 'ollama/ollama'

class ChatGPTSummary < Ollama
  def initialize(options:, logger:)
    super

    reaction_set('youyaku', 'AIに要約させる') { |data:, reaction:| summary(data, reaction) }
  end

  def summary(data, reaction)
    @logger.info "Received message for summary: #{reaction}"

    url = extract_url_from_messages(data)
    return handle_no_url(data) if url.nil?

    content = fetch_and_extract_content(url)
    return handle_empty_content(data) if content.empty?

    response = generate_summary(content)
    return handle_summary_failure(data) if response_invalid?(response)

    send_summary_response(data, response)
  rescue StandardError => e
    handle_error(e, data)
  end

  private

  def extract_url_from_messages(data)
    messages = data.messages
    word = messages.first[:text]
    url = extract_urls(word)
    @logger.info "Extracted URLs: #{url}"
    url
  end

  def handle_no_url(data)
    data.say(text: 'URL Not Found', thread_ts: data.ts)
  end

  def fetch_and_extract_content(url)
    @logger.info "Fetching content from URL: #{url}"
    content = extract_content(url)
    @logger.info "Fetched content: #{content}"
    content
  end

  def handle_empty_content(data)
    data.say(text: 'コンテンツを取得できませんでした', thread_ts: data.ts)
  end

  def generate_summary(content)
    send_message(context: content, system_message: build_system_message)
  end

  def response_invalid?(response)
    response.nil? || response[:message].nil?
  end

  def handle_summary_failure(data)
    data.say(text: '要約の生成に失敗しました', thread_ts: data.ts)
  end

  def send_summary_response(data, response)
    summary_response = response[:message][:content]
    @logger.info "ChatGPT Summary response: #{summary_response}"
    data.say(text: summary_response, thread_ts: data.ts)
  end

  def handle_error(error, data)
    @logger.error "Error in summary: #{error.message}"
    data.say(text: "エラーが発生しました: #{error.message}", thread_ts: data.ts)
  end

  def extract_urls(text)
    # Slack形式のURLを抽出する正規表現
    slack_url_match = text.match(%r{<(https?://[^|>]+)(?:\|[^>]+)?>})
    return slack_url_match[1] if slack_url_match

    # 通常のHTTP/HTTPSのURLを抽出する正規表現
    url_match = text.match(%r{https?://[^\s]+})
    return url_match[0] if url_match

    nil
  end

  def extract_content(url)
    html = fetch_html_content(url)
    doc = parse_and_clean_html(html)
    extract_best_content(doc)
  end

  def fetch_html_content(url)
    URI.parse(url).read
  rescue StandardError => e
    raise StandardError, "コンテンツの取得に失敗しました: #{e.message}"
  end

  def parse_and_clean_html(html)
    doc = Nokogiri::HTML.parse(html)
    remove_noise_elements(doc)
    remove_utility_elements(doc)
    doc
  end

  def remove_noise_elements(doc)
    noise_selectors = %w[script style noscript iframe svg canvas form input footer nav header aside]
    doc.search(noise_selectors.join(', ')).remove
  end

  def remove_utility_elements(doc)
    utility_selectors = [
      "[class*='comment']", "[id*='comment']", "[class*='share']",
      "[class*='social']", "[class*='ads']", "[id*='ads']"
    ]
    doc.css(utility_selectors.join(', ')).remove
  end

  def extract_best_content(doc)
    candidates = doc.search('article, main, section, div')
    best_node = find_best_content_node(candidates)
    return '' unless best_node

    format_content_text(best_node)
  end

  def find_best_content_node(candidates)
    best_node = nil
    best_score = -Float::INFINITY

    candidates.each do |node|
      score = calculate_content_score(node)
      if score > best_score
        best_score = score
        best_node = node
      end
    end

    best_node
  end

  def format_content_text(node)
    paragraphs = node.css('p').map { |p| p.text.strip }.reject(&:empty?)
    body = if paragraphs.any?
             paragraphs.join("\n\n")
           else
             node.text.strip
           end

    # 余計な連続改行調整
    body.gsub(/\n{3,}/, "\n\n").strip
  end

  def calculate_content_score(node)
    text = normalize_text(node.text)
    return -Float::INFINITY if text.length < 200 # 短すぎるのは除外

    base_score = calculate_base_score(node, text)
    link_density = calculate_link_density(node, text)
    penalty = calculate_penalty(node)
    punct_bonus = calculate_punctuation_bonus(text)

    (base_score * (1.0 - link_density)) + punct_bonus - penalty
  end

  def normalize_text(text)
    text.strip.gsub(/\s+/, ' ')
  end

  def calculate_base_score(node, text)
    p_count = node.css('p').count
    text.length + (p_count * 50)
  end

  def calculate_link_density(node, text)
    link_text_len = node.css('a').map { |a| a.text.length }.sum
    link_text_len.to_f / [text.length, 1].max
  end

  def calculate_penalty(node)
    klass = "#{node['class']} #{node['id']}".downcase
    penalty = 0
    penalty += 200 if klass =~ /(nav|menu|breadcrumb|footer|header|sidebar|related|recommend)/
    penalty += 100 if klass =~ /(list|grid|card|thumb)/
    penalty
  end

  def calculate_punctuation_bonus(text)
    jp_punct = text.count('。．、，')
    jp_punct * 3
  end

  def build_system_message
    <<~SYSTEM_MESSAGE
      内容を下記のフォーマットで日本語で要約してください。
      要約の際は、以下のルールを守ってください。
      1. Markdown記法は絶対使用しないでください。
      2. 重要なポイントを箇条書きでまとめる
      3. 各ポイントは簡潔に、かつ具体的に記述
      4. 文体はフォーマルで、専門用語を避ける
      5. 読み手が理解しやすいように、論理的な流れを保つ
      6. 可能であれば、具体例やデータを引用して信頼性を高める
      7. 最後に、要約の結論を一文で述べる
      8. 文章は日本語で書くこと

      フォーマット:
      ---
      3行まとめ:
        - ポイント1: [要約内容]
        - ポイント2: [要約内容]
        - ポイント3: [要約内容]

      要約:
      [要約内容]
      参考:
      [参考情報やリンク]
      以上のフォーマットに従って、要約を作成してください。
    SYSTEM_MESSAGE
  end
end
