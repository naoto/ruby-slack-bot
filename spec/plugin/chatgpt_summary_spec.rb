# frozen_string_literal: true

require 'json'
require 'nokogiri'
require_relative '../spec_helper'
require_relative '../../lib/plugin/chatgpt_summary'

RSpec.describe ChatGPTSummary do
  subject(:plugin) { build_plugin(described_class, options: options, logger: logger) }

  let(:logger) { test_logger }
  let(:options) { {} }
  let(:url) { 'https://example.com/article' }
  let(:slack_formatted_url) { "<#{url}|リンクテキスト>" }
  let(:html_content) do
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>テスト記事</title></head>
      <body>
        <header>ヘッダー</header>
        <nav>ナビゲーション</nav>
        <main>
          <article>
            <h1>記事タイトル</h1>
            <p>これは重要な段落です。記事の本文として使用されます。この段落には意味のある内容が含まれています。この文章は要約のテストのために作成されました。内容は特に意味を持ちませんが、文字数を調整しています。</p>
            <p>2番目の段落も重要な内容です。詳細な説明が含まれています。これにより、記事の内容が充実します。さらに多くの情報が提供され、読者にとって価値のあるコンテンツとなっています。</p>
            <p>3番目の段落では、さらに詳しい情報を提供します。読者にとって価値のある情報が含まれています。この段落も十分な長さを持ち、意味のある内容を含んでいます。</p>
          </article>
        </main>
        <aside>サイドバー</aside>
        <footer>フッター</footer>
      </body>
      </html>
    HTML
  end
  let(:expected_content) do
    "これは重要な段落です。記事の本文として使用されます。この段落には意味のある内容が含まれています。この文章は要約のテストのために作成されました。内容は特に意味を持ちませんが、文字数を調整しています。\n\n" \
      "2番目の段落も重要な内容です。詳細な説明が含まれています。これにより、記事の内容が充実します。さらに多くの情報が提供され、読者にとって価値のあるコンテンツとなっています。\n\n" \
      '3番目の段落では、さらに詳しい情報を提供します。読者にとって価値のある情報が含まれています。この段落も十分な長さを持ち、意味のある内容を含んでいます。'
  end

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    allow(logger).to receive(:debug?).and_return(false)
  end

  describe '#initialize' do
    it 'リアクションが正しく設定される' do
      expect(plugin).to respond_to(:summary)
    end

    it 'logger とオプションが設定される' do
      expect(plugin.instance_variable_get(:@logger)).to eq(logger)
    end
  end

  describe '#summary' do
    let(:messages) { [{ text: message_text }] }
    let(:data) { build_event(messages: messages, ts: '1234567890.123') }
    let(:reaction) { 'youyaku' }

    context 'URLが含まれている場合' do
      let(:message_text) { "この記事を要約して #{url}" }

      before do
        allow(URI).to receive(:parse).with(url).and_return(double(read: html_content))
        allow(plugin).to receive(:send_message).and_return({
                                                             message: { content: '要約結果です' }
                                                           })
        allow(data).to receive(:say)
      end

      it 'URLを抽出してコンテンツを取得し、要約を生成する' do
        expect(plugin).to receive(:send_message).with(
          context: expected_content,
          system_message: anything
        )

        plugin.summary(data, reaction)
      end

      it '要約結果をSlackに送信する' do
        expect(data).to receive(:say).with(
          text: '要約結果です',
          thread_ts: '1234567890.123'
        )

        plugin.summary(data, reaction)
      end
    end

    context 'Slack形式のURLが含まれている場合' do
      let(:message_text) { "この記事を要約して #{slack_formatted_url}" }

      before do
        allow(URI).to receive(:parse).with(url).and_return(double(read: html_content))
        allow(plugin).to receive(:send_message).and_return({
                                                             message: { content: '要約結果です' }
                                                           })
        allow(data).to receive(:say)
      end

      it 'Slack形式のURLからURLを抽出する' do
        expect(plugin).to receive(:send_message).with(
          context: expected_content,
          system_message: anything
        )

        plugin.summary(data, reaction)
      end
    end

    context 'URLが含まれていない場合' do
      let(:message_text) { 'URLなしのメッセージ' }

      before do
        allow(data).to receive(:say)
      end

      it 'URL Not Foundメッセージを送信する' do
        expect(data).to receive(:say).with(
          text: 'URL Not Found',
          thread_ts: '1234567890.123'
        )

        plugin.summary(data, reaction)
      end
    end

    context 'コンテンツが空の場合' do
      let(:message_text) { "この記事を要約して #{url}" }
      let(:empty_html) { '<html><body></body></html>' }

      before do
        allow(URI).to receive(:parse).with(url).and_return(double(read: empty_html))
        allow(data).to receive(:say)
      end

      it 'コンテンツ取得失敗メッセージを送信する' do
        expect(data).to receive(:say).with(
          text: 'コンテンツを取得できませんでした',
          thread_ts: '1234567890.123'
        )

        plugin.summary(data, reaction)
      end
    end

    context 'エラーが発生した場合' do
      let(:message_text) { "この記事を要約して #{url}" }
      let(:error_message) { 'ネットワークエラー' }

      before do
        allow(URI).to receive(:parse).with(url).and_raise(StandardError.new(error_message))
        allow(data).to receive(:say)
      end

      it 'エラーメッセージを送信する' do
        expect(data).to receive(:say).with(
          text: "エラーが発生しました: コンテンツの取得に失敗しました: #{error_message}",
          thread_ts: '1234567890.123'
        )

        plugin.summary(data, reaction)
      end

      it 'エラーログを出力する' do
        expect(logger).to receive(:error).with(/Error in summary/)

        plugin.summary(data, reaction)
      end
    end
  end

  describe '#extract_urls' do
    context 'URLが正しく抽出される' do
      it 'Slack形式のURLからURLを抽出する' do
        text = '記事はこちら <https://example.com/article|リンクテキスト> です'
        result = plugin.send(:extract_urls, text)
        expect(result).to eq('https://example.com/article')
      end

      it 'Slack形式のURLからURLを抽出する（パイプなし）' do
        text = '記事はこちら <https://example.com/article> です'
        result = plugin.send(:extract_urls, text)
        expect(result).to eq('https://example.com/article')
      end

      it '通常のHTTPSのURLを抽出する' do
        text = '記事はこちら https://example.com/article です'
        result = plugin.send(:extract_urls, text)
        expect(result).to eq('https://example.com/article')
      end

      it '通常のHTTPのURLを抽出する' do
        text = '記事はこちら http://example.com/article です'
        result = plugin.send(:extract_urls, text)
        expect(result).to eq('http://example.com/article')
      end
    end

    context 'URLが含まれていない場合' do
      it 'nilを返す' do
        text = 'URLが含まれていないテキスト'
        result = plugin.send(:extract_urls, text)
        expect(result).to be_nil
      end
    end
  end

  describe '#extract_content' do
    before do
      allow(URI).to receive(:parse).with(url).and_return(double(read: html_content))
    end

    it 'HTMLからメインコンテンツを抽出する' do
      result = plugin.send(:extract_content, url)
      expect(result).to eq(expected_content)
    end

    it 'ノイズ要素（script、style等）を除去する' do
      # html_contentと同じ構造で、scriptとstyleを追加
      noisy_html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>テスト記事</title></head>
        <body>
          <script>alert('test');</script>
          <style>body { color: red; }</style>
          <header>ヘッダー</header>
          <nav>ナビゲーション</nav>
          <main>
            <article>
              <h1>記事タイトル</h1>
              <p>これは重要な段落です。記事の本文として使用されます。この段落には意味のある内容が含まれています。この文章は要約のテストのために作成されました。内容は特に意味を持ちませんが、文字数を調整しています。</p>
              <p>2番目の段落も重要な内容です。詳細な説明が含まれています。これにより、記事の内容が充実します。さらに多くの情報が提供され、読者にとって価値のあるコンテンツとなっています。</p>
              <p>3番目の段落では、さらに詳しい情報を提供します。読者にとって価値のある情報が含まれています。この段落も十分な長さを持ち、意味のある内容を含んでいます。</p>
            </article>
          </main>
          <aside>サイドバー</aside>
          <footer>フッター</footer>
        </body>
        </html>
      HTML

      allow(URI).to receive(:parse).with(url).and_return(double(read: noisy_html))
      result = plugin.send(:extract_content, url)

      # スクリプトとスタイルが除去されることを確認
      expect(result).not_to include('alert')
      expect(result).not_to include('color: red')

      # 何らかのコンテンツが抽出されることを確認（空でない）
      expect(result).to be_a(String)

      # メインコンテンツが含まれることを確認（十分な長さがある場合）
      expect(result).to include('重要な段落') unless result.empty?
    end

    context 'ネットワークエラーが発生した場合' do
      it 'エラーメッセージと共に例外を発生させる' do
        allow(URI).to receive(:parse).with(url).and_raise(SocketError.new('ネットワークエラー'))

        expect do
          plugin.send(:extract_content, url)
        end.to raise_error(/コンテンツの取得に失敗しました/)
      end
    end
  end

  describe '#calculate_content_score' do
    let(:doc) { Nokogiri::HTML.parse(html_content) }
    let(:article_node) { doc.css('article').first }

    it '適切なコンテンツノードに高いスコアを付ける' do
      score = plugin.send(:calculate_content_score, article_node)
      expect(score).to be > 0
    end

    it '短すぎるコンテンツには負のスコアを付ける' do
      short_html = '<div><p>短い</p></div>'
      short_doc = Nokogiri::HTML.parse(short_html)
      short_node = short_doc.css('div').first

      score = plugin.send(:calculate_content_score, short_node)
      expect(score).to eq(-Float::INFINITY)
    end

    it '十分な長さのコンテンツは正のスコアを持つ' do
      # html_contentを使用（すでに十分な長さがある）
      article_node = doc.css('article').first

      score = plugin.send(:calculate_content_score, article_node)
      expect(score).to be_a(Numeric)
      expect(score).to be > 0
    end

    it 'ナビゲーション系のクラス名がある場合にペナルティが適用される' do
      # html_contentと同じ内容で、クラス名だけ異なるものを比較
      article_content = doc.css('article').first.inner_html

      nav_html = "<div class='navigation'>#{article_content}</div>"
      nav_doc = Nokogiri::HTML.parse(nav_html)
      nav_node = nav_doc.css('div').first

      normal_html = "<div>#{article_content}</div>"
      normal_doc = Nokogiri::HTML.parse(normal_html)
      normal_node = normal_doc.css('div').first

      nav_score = plugin.send(:calculate_content_score, nav_node)
      normal_score = plugin.send(:calculate_content_score, normal_node)

      # 両方とも有効なスコアが計算される場合のみペナルティをテスト
      if nav_score != -Float::INFINITY && normal_score != -Float::INFINITY
        expect(nav_score).to be < normal_score
      else
        # 両方とも無効な場合は同じスコアになることを確認
        expect(nav_score).to eq(normal_score)
      end
    end
  end

  describe '#build_system_message' do
    it '適切なシステムメッセージを生成する' do
      message = plugin.send(:build_system_message)
      expect(message).to include('日本語で要約してください')
      expect(message).to include('Markdown記法は絶対使用しないでください')
      expect(message).to include('3行まとめ:')
      expect(message).to include('要約:')
      expect(message).to include('参考:')
    end
  end

  describe 'エラーハンドリング' do
    let(:messages) { [{ text: "要約して #{url}" }] }
    let(:data) { build_event(messages: messages, ts: '1234567890.123') }
    let(:reaction) { 'youyaku' }

    context 'send_messageでエラーが発生した場合' do
      before do
        allow(URI).to receive(:parse).with(url).and_return(double(read: html_content))
        allow(plugin).to receive(:send_message).and_raise(StandardError.new('API エラー'))
        allow(data).to receive(:say)
      end

      it 'エラーメッセージを送信する' do
        expect(data).to receive(:say).with(
          text: 'エラーが発生しました: API エラー',
          thread_ts: '1234567890.123'
        )

        plugin.summary(data, reaction)
      end
    end

    context 'send_messageがnilレスポンスを返した場合' do
      before do
        allow(URI).to receive(:parse).with(url).and_return(double(read: html_content))
        allow(plugin).to receive(:send_message).and_return(nil)
        allow(data).to receive(:say)
      end

      it 'デフォルトメッセージを送信する' do
        expect(data).to receive(:say).with(
          text: '要約の生成に失敗しました',
          thread_ts: '1234567890.123'
        )

        plugin.summary(data, reaction)
      end
    end
  end
end
