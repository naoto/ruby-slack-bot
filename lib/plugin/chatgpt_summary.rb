# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'
require_relative 'ollama/ollama'

class ChatGPTSummary < Ollama
  def initialize(options:, logger:)
    super(options: options, logger: logger)

    reaction_set('youyaku', 'AIに要約させる') { |data:, reaction:| summary(data, reaction) }
  end

  def summary(data, reaction)
    @logger.info "Received message for summary: #{reaction}"

    messages = data.messages
    word = messages.first[:text]
    url = extract_urls(word)
    @logger.info "Extracted URLs: #{url}"

    if url.nil?
      data.say(text: "URL Not Found", thread_ts: data.ts)
      return
    end

    @logger.info "Fetching content from URL: #{url}"

    content = extract_content(url)
    @logger.info "Fetched content: #{content}"

    if content.empty?
      data.say(text: "コンテンツを取得できませんでした", thread_ts: data.ts)
      return
    end

    response = send_message(context: content, system_message: build_system_message)
    
    if response.nil? || response[:message].nil?
      data.say(text: "要約の生成に失敗しました", thread_ts: data.ts)
      return
    end

    summary_response = response[:message][:content]
    @logger.info "ChatGPT Summary response: #{summary_response}"

    data.say(text: summary_response, thread_ts: data.ts)
  rescue StandardError => e
    @logger.error "Error in summary: #{e.message}"
    error_message = if e.message.include?("コンテンツの取得に失敗しました")
                      "エラーが発生しました: #{e.message}"
                    else
                      "エラーが発生しました: #{e.message}"
                    end
    data.say(text: error_message, thread_ts: data.ts)
  end

  private

  def extract_urls(text)
    # Slack形式のURLを抽出する正規表現
    slack_url_match = text.match(/<(https?:\/\/[^|>]+)(?:\|[^>]+)?>/)
    return slack_url_match[1] if slack_url_match

    # 通常のHTTP/HTTPSのURLを抽出する正規表現
    url_match = text.match(/https?:\/\/[^\s]+/)
    return url_match[0] if url_match

    nil
  end

  def extract_content(url)
    begin
      html = URI.parse(url).read
    rescue => e
      raise StandardError, "コンテンツの取得に失敗しました: #{e.message}"
    end

    doc = Nokogiri::HTML.parse(html)

    # ノイズ除去
    doc.search("script, style, noscript, iframe, svg, canvas, form, input, footer, nav, header, aside").remove

    # 明らかなユーティリティ要素を間引き
    doc.css("[class*='comment'], [id*='comment'], [class*='share'], [class*='social'], [class*='ads'], [id*='ads']").remove

    # 候補ブロック: <article>, <main>, <section>, <div>, <p> など
    candidates = doc.search("article, main, section, div")

    best_node = nil
    best_score = -Float::INFINITY

    candidates.each do |node|
      score = calculate_content_score(node)
      
      if score > best_score
        best_score = score
        best_node = node
      end
    end

    return "" unless best_node

    # <p> のない長大ラッパを避けるため、最終的に <p> を束ね直す
    paragraphs = best_node.css("p").map { |p| p.text.strip }.reject { |t| t.empty? }
    body = if paragraphs.any?
            paragraphs.join("\n\n")
          else
            best_node.text.strip
          end

    # 余計な連続改行調整
    body.gsub(/\n{3,}/, "\n\n").strip
  end

  def calculate_content_score(node)
    text = node.text.strip.gsub(/\s+/, " ")
    return -Float::INFINITY if text.length < 200  # 短すぎるのは除外

    # 基本スコア: 文字数 & <p> の数
    p_count = node.css("p").count
    base = text.length + (p_count * 50)

    # リンク密度: aタグ中の文字数 / 総文字数
    link_text_len = node.css("a").map { |a| a.text.length }.sum
    link_density = (link_text_len.to_f / [text.length, 1].max)

    # メタ/ラッパ感のあるクラス名を減点
    klass = (node["class"].to_s + " " + node["id"].to_s).downcase
    penalty = 0
    penalty += 200 if klass =~ /(nav|menu|breadcrumb|footer|header|sidebar|related|recommend)/
    penalty += 100 if klass =~ /(list|grid|card|thumb)/

    # 日本語向け: 句点・読点が多いほど加点（文の連続=本文っぽい）
    jp_punct = text.count("。．、，")
    punct_bonus = jp_punct * 3

    score = base * (1.0 - link_density) + punct_bonus - penalty
    score
  end

  def build_system_message
    <<'SYSTEM_MESSAGE'
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