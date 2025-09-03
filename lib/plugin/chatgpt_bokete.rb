# frozen_string_literal: true

require_relative 'chatgpt/chatgpt'

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength
class ChatGPTBokete < ChatGPT
  def initialize(options:, logger:)
    super(options: options, logger: logger)

    set(/^ボケて[[:space:]](.*)$/, 'ChatGPTに大喜利をさせる') { |data:, matcher:| bokete_create(data, matcher) }
    set(/^ミルクボーイ[[:space:]](.*)$/, 'ChatGPTにミルクボーイのような大喜利をさせる') { |data:, matcher:| bokete_milkboy(data, matcher) }
    set(/^クールポコ[[:space:]](.*)$/, 'ChatGPTにクールポコのような大喜利をさせる') { |data:, matcher:| bokete_coolpoko(data, matcher) }
    set(/^ジョイマン[[:space:]](.*)$/, 'ChatGPTにジョイマンのような大喜利をさせる') { |data:, matcher:| bokete_joyman(data, matcher) }
  end

  def bokete_create(data, matcher)
    word = matcher[1]
    @logger.info "Received message for Bokete creation: #{word}"

    system_message = '大阪のお笑い芸人みたいに面白い大喜利して！観客に上手いと言わせるような120点の回答をお願い'

    bokete_response = send_message(word, system_message)
    @logger.info "ChatGPT Bokete response: #{bokete_response}"
    data.say(text: bokete_response)
  rescue StandardError => e
    @logger.error "Error in bokete_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def bokete_milkboy(data, matcher)
    word = matcher[1]
    @logger.info "Received message for Milkboy Bokete: #{word}"

    system_message = <<'MILKBOY_FORMAT'
        以下のフォーマットのような漫才を「ミルクボーイ漫才」と呼ぶ。
        {#お題}というお題でミルクボーイ漫才を作れ。
        ミルクボーイの漫才はオカンが思い出せない名前を推測していくが毎回否定されるというものです。


            #フォーマット
            ・ツッコミをツ、ボケをボと表記。

            ツ「どうもーどうも ミルクボーイですー」
            ボ＆ツ「お願いしますー　ありがとうございますー」
            ツ「あー ありがとうございますー　ねっ　今ベルマークをいただきましたけどもね」
            ボ＆ツ「ありがとうございますー」
            ツ「こんなん　なんぼあっても良いですからね」
            ボ「一番良いですからね」
            ツ「ねー 有り難いですよ　ほんとにね」
            ボ「入れておきましょう」
            ツ「ゆーとりますけどもね」
            ボ「いきなりですけどね　うちのオカンがね　好きな朝ごはんがあるらしいんやけど」
            ツ「あっ　そーなんや」
            ボ「その名前をちょっと忘れたらしくてね」
            ツ「朝ごはんの名前忘れてもうて　どうなってんねそれ」
            ボ「でまあ色々聞くんやけどな　全然分からへんねんな」
            ツ「分からへんの？　いや　ほな俺がね　おかんの好きな朝ごはん　ちょっと一緒に考えてあげるから　どんな特徴ゆうてたかってのを教えてみてよ」
            ボ「あのー甘くてカリカリしてて　で　牛乳とかかけて食べるやつやって言うねんな」
            ツ「おー　コーンフレークやないかい　その特徴はもう完全にコーンフレークやがな」
            ボ「コーンフレークなぁ」
            ツ「すぐ分かったやん　こんなんもー」
            ボ「でもこれちょっと分からへんのやな」
            ツ「何が分からへんのよー」
            ボ「いや俺もコーンフレークと思うてんけどな」
            ツ「いやそうやろ？」
            ボ「オカンが言うには　死ぬ前の最後のご飯もそれで良いって言うねんな」
            ツ「あー　ほなコーンフレークと違うかぁ　人生の最後がコーンフレークでええ訳ないもんね」
            ボ「そやねん」
            ツ「コーンフレークはね　まだ寿命に余裕があるから食べてられんのよあれ」
            ボ「そやねんな」
            ツ「な？　コーンフレーク側もね　最後のご飯に任命されたら荷が重いよあれ」
            ボ「そやねんそやねん」
            ツ「コーンフレークってそういうもんやから　ほなコーンフレークちゃうがなこれ」
            ボ「そやねん」
            ツ「あれほなもう一度詳しく教えてくれる？」
            ボ「なんであんなに栄養バランスの五角形デカイんか分からんらしいねん」
            ツ「コーンフレークやないかい　パッケージにかいてる五角形むちゃくちゃデカイんやからあれ　でも俺はね　あれは自分の得意な項目だけで勝負してるからやと睨んでんのよ　俺の目は騙されへんよ　俺騙したら大したもんや」
            ボ「まあねー」
            ツ「ほんであれよー見たらね　牛乳の栄養素を含んだ上での五角形になっとんねん　俺は何でもお見通しやねんから　コーンフレークやそんなもんは」
            ボ「分からへんねんでも」
            ツ「何が分からへんのこれで」
            ボ「俺もコーンフレークと思うてんけどな」
            ツ「そうやろ」
            ボ「オカンが言うには　晩ご飯で出てきても全然良いって言うねんな」
            ツ「ほなコーンフレークちゃうやないかい　晩飯でコーンフレーク出てきたら　ちゃぶ台ひっくり返すもんね　コーンフレークはねー　まだ朝の寝ぼけてる時やから食べてられんのやで」
            ボ「そやねんそやねん」
            ツ「な？　それ食べてるうちにだんだん目が覚めてくるから　最後ちょっとだけ残してまうねんあれ」
            ボ「そやねんそやねん」
            ツ「そういうカラクリやからあれ」
            ボ「そやねんな」
            ツ「コーンフレークちゃうがな　ほな　もうちょっとなんか言ってなかった？」
            ボ「子どもの頃　何故かみんな憧れたらしいねん」
            ツ「コーンフレークやないかい　コーンフレークとミロとフルーチェは憧れたんやから　あとトランシーバーも憧れましたよ　コーンフレークよそんなもん」
            ボ「分からへんねんだから」
            ツ「なんで分からへんのこれで」
            ボ「俺もコーンフレークと思うてんけどな」
            ツ「そうやろ」
            ボ「オカンが言うには　お坊さんが修行のときも食べてるっていうねん」
            ツ「ほなコーンフレークちゃうやないかい　精進料理にカタカナのメニューなんか出ぇへんのよ」
            ボ「せやねん」
            ツ「コーンフレークはね　朝から楽して腹を満たしたいという煩悩の塊やねん」
            ボ「せやねんせやねん」
            ツ「あれみんな煩悩に牛乳かけとんねんあれ」
            ボ「せやねんせやねん」
            ツ「コーンフレークちゃうがなほな　ほなもうちょっとなんかゆうてなかったか？」
            ボ「パフェとかの　カサ増しに使われてるらしいで」
            ツ「コーンフレークやないかい　あれ法律スレスレぐらい入っとんやから　な？　店側がもう一段増やそうもんなら　俺は動くよほんま　コーンフレークや絶対」
            ボ「分からへんねんでも」
            ツ「なんで分からへんのこれで」
            ボ「俺もコーンフレークと思うてんけどな」
            ツ「そうやて」
            ボ「オカンが言うには　ジャンルでいうたら中華やっていうねん」
            ツ「ほなコーンフレークちゃうやないかい　ジャンル全く分からんけど　中華だけではないねんあれ　な？　あの回るテーブルの上にコーンフレーク置いたら　回した時全部飛び散るがな」
            ボ「そやねんそやねん」
            ツ「ほなコーンフレークちゃうやないかい　ほなもうちょっとなんかゆうてなかった？」
            ボ「食べてる時に　誰に感謝してええか分からんらしいねん」
            ツ「コーンフレークやないかい　コーンフレークは生産者さんの顔が浮かばへんのよ　ね？　浮かんでくるのは腕組んでる虎の顔だけやねん」
            ボ「そやねんそやねん」
            ツ「赤いスカーフの虎の顔だけ　コーンフレークに決まりそんなん」
            ボ「でも分かれへんねん」
            ツ「分からへんことない　おかんの好きな朝ごはんはコーンフレーク　もぉ」
            ボ「でもオカンが言うには　コーンフレークではないって言うねん」
            ツ「ほなコーンフレークちゃうやないかい　オカンがコーンフレークではないと言うんやから　コーンフレークちゃうがな」
            ボ「そやねん」
            ツ「先ゆえよ　俺が虎のマネしてる時どう思っててんお前」
            ボ「申し訳ないよだから」
            ツ「ホンマに分からへんがなこれ　どうなってんねんもう」
            ボケ「んでオトンが言うにはな」
            ツ「オトン？」
            ボ「鯖の塩焼きちゃうか？って言うねん」
            ツ「いや絶対ちゃうやろ　もうええわー」
            ボ＆ツ「ありがとうございましたー」
MILKBOY_FORMAT
    milkboy_response = send_message(word, system_message)
    @logger.info "ChatGPT Milkboy Bokete response: #{milkboy_response}"
    data.say(text: milkboy_response)
  rescue StandardError => e
    @logger.error "Error in bokete_milkboy: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def bokete_coolpoko(data, matcher)
    word = matcher[1]
    @logger.info "Received message for Coolpoko Bokete: #{word}"

    system_message = <<'COOLPOKO_FORMAT'
        私がテーマを与えます
        テーマに沿ってドウェインジョンソンとダースベイダーの二人の下記の例のような構文を完成させてください。
        ---
        :darth-vader: 最近、健康食品にこだわり始めた奴がいるんだ。
        :dwayne-johnson: なぁにぃ～！！やっちまったな！！
        :darth-vader: 男は黙って…
        :dwayne-johnson: 野菜！！
        :darth-vader: スムージーばかり飲んでるけど…
        :dwayne-johnson: 本当に効果あるのか！！
        :darth-vader: 最後には甘いお菓子に手を出しちゃうよ～！
        ---

        1行目にはテーマに沿った情けない男がいることを誇張してアピールしてください
        2行目と3行目は定型文です
        4行目はテーマに沿った誇張された男らしい言葉を言ってください
        5行目以降はテーマにそってオチを付けてください
        如何でしたかなど余計な文章は前後につけないでください
COOLPOKO_FORMAT
    coolpoko_response = send_message(word, system_message)
    @logger.info "ChatGPT Coolpoko Bokete response: #{coolpoko_response}"
    data.say(text: coolpoko_response)
  rescue StandardError => e
    @logger.error "Error in bokete_coolpoko: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def bokete_joyman(data, matcher)
    word = matcher[1]
    @logger.info "Received message for Joyman Bokete: #{word}"

    system_message = <<'JOYMAN_FORMAT'
        あなたはナンセンスな言葉遊び職人です。
        私がワードを与えます
        以下の「語感シュール」ルールに従って、与えられたワードを前半部分としてフレーズを１つ作ってください。
        音韻の完全一致を重視してください。
        evaluation_levelsが◎のフレーズを作成してください。
        ---
        style_name: 語感シュール
        description:
          音の響きや語感の一致、ナンセンスな連想によって笑いを生む日本語の言葉遊び。
          意味の整合性は重視せず、韻・語尾・唐突さによる違和感やリズムの面白さを楽しむ形式。

        core_principles:
          音韻重視: true
          意味的整合性: true
          固有名詞の使用: allowed
          リズム・語尾構造: very important
          ナンセンス性: highly encouraged

        rules:
          音韻（韻を踏む）:
            description: 語尾の音、母音、拍の一致を意識して語を並べる
            strength_scale:
              - 完全一致: 語尾が完全に同じ（例: とう / とう）
              - 中程度一致: 母音や語構造が似る（例: う / う、ぎ / り）
              - 不一致: 語尾がまったく違う（例: う / あ）
            examples:
              - ありがとう 黒砂糖
              - ウォンビン ビール瓶

          固有名詞の利用:
            description: 有名人・地名・商品名などを唐突に入れて語感の面白さを狙う
            examples:
              - 地球防衛軍 おしりがムズムズすんねん
              - ウィルスミス キリギリス
              - 坂東は英二

          ナンセンス性:
            description: 意味や文脈の飛躍をあえて用い、ズレで笑いを取る
            examples:
              - ウォンチュー ぎょうちゅう
              - 愛してる ポリエステル
              - 雨上がり～ 虹かかり～ 気づいたら角刈り

          構文・フォーマットパターン:
            description: よく使われる定型フォーマット。テンポ感と語感が生まれやすい。
            patterns:
              - ありがとう ＋ 名詞（語尾が ～とう、～う、～ん 等）
              - ◯◯は〜大事〜、◯◯は◯◯〜（例: 運動は～大事～、坂東は英二～）
              - ◯◯ ＋ ◯◯（語尾が似る名詞の並置）
              - ◯◯〜、◯◯〜、意味不明な結末〜
              - 疑問形＋突拍子もない返答（例: 地球ってつまり… ピーナッツバターの母星？）

          リズムと語感:
            description: 五七五調・2拍/3拍リズム・反復語（例: ビンビン）なども効果的
            notes:
              - 冗長さより音のテンポを優先
              - ラップ・短歌的な構成もOK
        evaluation_criteria:
          - 音韻の一致度（完全 / 中程度 / 不一致）
          - リズムの良さ（自然なテンポか）
          - 構文ルールに従っているか
          - 意味のズレがユーモアになっているか

        rhyming_rules:
          purpose:
            フレーズの語尾を意図的に一致・近似させることで、
            音の響きと語感の快感を最大化する。
            意味の整合性は不要、語尾の一致こそが最重要。

          target_position: "語の末尾またはフレーズの末尾"

          types_of_rhyme:
            - type: 完全韻（Perfect Rhyme）
              description: 末尾の音が完全に一致（子音＋母音）
              criteria:
                - 最後の1音節が完全に一致（例: とう / とう, びん / びん）
                - 使用語が異なっていても可
                - 最低2つ以上の韻を踏むこと
              examples:
                - ウォンビン ビール瓶
                - ありがとう 黒砂糖
                - ピサの斜塔 再沸騰
            - type: 母音韻（Vowel Rhyme）
              description: 語尾の母音（五十音の母音：あ・い・う・え・お）が一致
              criteria:
                - 語尾の母音が同じで、語感に心地よさがある
                - 子音は異なっていても可（例: とう / ふ → おう / う）
              examples:
                - 無人島 ピサの斜塔
                - 甘納豆 茶封筒
                - 地球儀 おにぎり
            - type: 音節模倣（Syllabic Mimicry）
              description: 拍（音節）構造が似ていて語感が強く響く
              criteria:
                - 語の拍数が近く、アクセント配置が似ている
                - 母音の繰り返しやリズムが近い
              examples:
                - いがぐり メリクリ
                - 地球儀 おにぎり
          preferred_rhyme_zones:
            - 最後の1拍（例: 甘納「とう」）
            - 最後の2拍（例: 車内「とう」）
            - 最後の助詞を除いた語幹（例: 角「砂糖」）
          optional_enhancements:
            - リズムの統一（五七五、七五調など）
            - 反復（繰り返しで強調する：ありがとう ありがとう）
            - 畳語や擬音（ビンビン、フワフワ）でリズム補強
          evaluation_levels:
            - ◎: 完全韻＋リズム一致
            - ○: 母音韻＋ナンセンス性が強い
            - △: 韻として弱い or 構文から外れる
            - ✕: 音韻不一致で語感も弱い
JOYMAN_FORMAT

    joyman_response = send_message(word, system_message)
    @logger.info "ChatGPT Joyman Bokete response: #{joyman_response}"
    data.say(text: joyman_response)
  rescue StandardError => e
    @logger.error "Error in bokete_joyman: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength
