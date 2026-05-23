import SwiftUI

struct FancyIdeasView: View {
    let onUseIdea: (FancyIdea) -> Void

    private let groups = FancyIdeaStore.groups

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("选择一个灵感，再带入对话细化")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AgentClawDesign.primaryText)
                    .padding(.top, 14)

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AgentClawDesign.primaryText)
                            .padding(.top, 4)
                            .padding(.bottom, 6)

                        ideaGrid(items: group.items)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .background(AgentClawDesign.controlSurface)
    }

    private func ideaGrid(items: [FancyIdea]) -> some View {
        let rows = stride(from: 0, to: items.count, by: 2).map { index in
            Array(items[index..<min(index + 2, items.count)])
        }

        return VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 10) {
                    ForEach(rows[rowIndex]) { idea in
                        ideaCard(idea)
                    }

                    if rows[rowIndex].count == 1 {
                        Spacer()
                    }
                }
            }
        }
    }

    private func ideaCard(_ idea: FancyIdea) -> some View {
        Button(action: { onUseIdea(idea) }) {
            VStack(alignment: .leading, spacing: 0) {
                Image(idea.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 40, alignment: .leading)

                Text(idea.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AgentClawDesign.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .padding(.top, 14)

                Text(idea.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(AgentClawDesign.secondaryText)
                    .lineLimit(2)
                    .padding(.top, 4)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FancyIdea: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let scenario: String
    let prompt: String
    let imageName: String
    let accent: Color
}

struct FancyIdeaGroup: Identifiable {
    let id = UUID()
    let title: String
    let items: [FancyIdea]
}

enum FancyIdeaStore {
    static let groups: [FancyIdeaGroup] = [
        FancyIdeaGroup(title: "高效办公", items: Array(all[0..<3])),
        FancyIdeaGroup(title: "规律生活", items: Array(all[3..<9])),
        FancyIdeaGroup(title: "勤学智助", items: Array(all[9..<13])),
        FancyIdeaGroup(title: "闲趣伴侣", items: Array(all[13..<18])),
        FancyIdeaGroup(title: "财智洞察", items: Array(all[18..<20]))
    ]

    private static let accents: [Color] = [
        Color(red: 0.23, green: 0.47, blue: 0.95),
        Color(red: 0.92, green: 0.45, blue: 0.18),
        Color(red: 0.48, green: 0.34, blue: 0.82),
        Color(red: 0.22, green: 0.62, blue: 0.36),
        Color(red: 0.86, green: 0.32, blue: 0.56),
        Color(red: 0.18, green: 0.58, blue: 0.52),
        Color(red: 0.82, green: 0.25, blue: 0.23),
        Color(red: 0.12, green: 0.54, blue: 0.70),
        Color(red: 0.20, green: 0.63, blue: 0.82),
        Color(red: 0.35, green: 0.43, blue: 0.86),
        Color(red: 0.62, green: 0.43, blue: 0.25),
        Color(red: 0.23, green: 0.47, blue: 0.95),
        Color(red: 0.48, green: 0.34, blue: 0.82),
        Color(red: 0.92, green: 0.45, blue: 0.18),
        Color(red: 0.86, green: 0.32, blue: 0.56),
        Color(red: 0.22, green: 0.62, blue: 0.36),
        Color(red: 0.18, green: 0.58, blue: 0.52),
        Color(red: 0.82, green: 0.25, blue: 0.23),
        Color(red: 0.23, green: 0.47, blue: 0.95),
        Color(red: 0.48, green: 0.34, blue: 0.82)
    ]

    static let all: [FancyIdea] = zip(FancyIdeaContent.items.indices, FancyIdeaContent.items).map { index, item in
        FancyIdea(
            id: "fancy_idea_\(index + 1)",
            title: item.title,
            subtitle: item.subtitle,
            scenario: item.scenario,
            prompt: item.prompt,
            imageName: String(format: "idea_%02d", index + 1),
            accent: accents[index]
        )
    }
}

private enum FancyIdeaContent {
    static let items: [(title: String, subtitle: String, scenario: String, prompt: String)] = [
        (
            "热点资讯自动汇总",
            "还在一条条刷资讯？每日自动整理，不用费心查找，快速看懂当天重点",
            "早高峰通勤：出门前设置好，路上通过 INMO Air3 快速浏览当日热点，不耽误行程。\n会议准备：快速获取行业核心动态，避免会议中对热点信息一无所知。\n高效办公：过滤无效碎片化信息，精准捕捉关键政策、行业风向，助力决策。",
            "创建每日「8:00」定时任务，自动抓取当日「AI科技」领域全网热点、重要资讯及要闻摘要，整理成简洁的内容，准时推送至我的眼前。"
        ),
        (
            "创业点子可行性验证",
            "有想法不敢下手？帮你快速验证可行性，零成本少踩坑",
            "创业初期：有初步创业想法，想快速了解可行性，避免盲目投入。\n项目评估：对现有创业项目，补充多维度分析，优化落地思路。\n合作洽谈：向合作伙伴展示点子可行性，提供数据支撑。",
            "验证AR智能体办公场景自动化助手这个创业点子，从市场需求、竞争格局、成本投入、盈利模式四个维度分析，生成简易可行性报告。"
        ),
        (
            "痛点自动挖掘分析",
            "立项没方向？自动深挖市场痛点，一份报告帮你稳过评审",
            "产品立项：新产品立项前，快速掌握行业痛点，明确产品方向。\n竞品分析：了解竞品用户反馈，挖掘其不足，找到自身优势。\n方案优化：根据行业痛点，优化现有产品/方案，提升竞争力。",
            "挖掘AR智能体办公场景的核心用户痛点，抓取相关社交平台用户评论和行业数据，分类整理并生成调研简报，支持导出。"
        ),
        (
            "明日运动计划",
            "想运动又怕坚持不下来？每天帮你排好计划，到点喊你动起来",
            "健身计划：制定减肥、增肌等运动目标，生成合理计划，逐步落地。\n日常锻炼：想养成运动习惯，每日有明确计划，避免盲目锻炼。\n时间管理：合理分配运动时间，兼顾工作、学习与锻炼。",
            "我的运动目标是“每天跑步30分钟、每周3次”，生成明日运动计划，设置「18:30」提醒，支持语音打卡，计划可根据反馈调整。"
        ),
        (
            "每日吃什么推荐",
            "饭点不知道吃啥？报口味定位，健康餐单连店带路喂到嘴边",
            "日常做饭：不知道做什么饭，输入偏好，快速获取餐单与做法。\n健康饮食：想保持健康饮食，推荐低脂、清淡餐单，贴合健康需求。\n口味适配：根据“不辣、清淡”等偏好，推荐贴合口味的餐品，避免踩雷。",
            "推荐今日午餐和晚餐，偏好清淡、不辣、低脂，适合日常居家做法，提供每道菜的简易做法指引，兼顾营养均衡。"
        ),
        (
            "锻炼任务调整",
            "锻炼计划乱了？帮你重新安排锻炼节奏",
            "计划适配：原运动计划太累，调整为更温和的节奏，避免放弃。\n时间适配：工作繁忙，时间不够，调整运动时长，适配日常时间。\n循序渐进：根据自身状态，逐步调整运动强度，稳步提升体能。",
            "我觉得当前的运动计划太累，时间也不够，调整明日运动计划，将跑步30分钟改为快走20分钟，调整提醒时间为「19:00」。"
        ),
        (
            "目标拆解与打卡",
            "立的flag总倒？把大目标拆成小步骤，每天打卡追踪进度",
            "减肥目标：“减肥10斤”大目标，拆解为每日小任务，逐步实现。\n考证目标：备考证书，拆解每日学习任务，避免拖延，稳步推进。\n习惯目标：“坚持每天读书”，拆解为每日小任务，养成自律习惯。",
            "我的大目标是“3个月减肥10斤”，将其拆解为每日小目标（控制饮食、适量运动），支持语音打卡，每周生成减肥进度报表。"
        ),
        (
            "自律习惯管理",
            "好习惯总坚持不了？21天打卡+数据追踪帮你养成好习惯",
            "阅读习惯：想养成每天读书30分钟的习惯，通过打卡坚持。\n健康习惯：养成每天喝8杯水、早睡早起的习惯，提升身体素质。\n办公习惯：养成每天整理工作文档、复盘当日工作的习惯，提升效率。",
            "我想养成“每天读书30分钟”的习惯，发起21天打卡挑战，设置「21:00」提醒，支持语音打卡，每日给出鼓励建议，生成打卡数据报表。"
        ),
        (
            "实时天气查询与出行穿搭建议",
            "支持实时温度、湿度、风力、空气质量查询，未来 7 天天气预报，智能穿衣建议及极端天气预警",
            "日常出行：出门前查询天气，获取穿衣建议，避免着凉、淋雨。\n短途旅行：查询目的地天气，提前准备衣物、出行用品。\n极端预警：收到暴雨、高温等极端天气预警，提前做好防护。",
            "查询北京今日实时天气、未来7天天气预报，结合今日天气给出穿衣建议，若有极端天气及时预警，语音播报结果。"
        ),
        (
            "制定轻量学习规划",
            "一到备考就头大？把你的学习计划烂摊子全甩给我吧",
            "备考冲刺：雅思、考研等备考，制定合理学习计划，避免盲目复习。\n技能提升：学习 Python、AI 等技能，拆分学习内容，循序渐进。\n日常积累：培养阅读、外语等习惯，制定轻量计划，易坚持不费力。",
            "制定“备考雅思”的每周学习规划，每日学习1.5小时，重点覆盖听力和阅读，每周日进行一次复盘，计划可灵活调整。"
        ),
        (
            "深度内容讲解",
            "遇到难题卡壳想放弃？帮你拆解卡点，找到破局思路",
            "难题攻克：学习中遇到的难点、疑点，快速获取通俗讲解，突破学习瓶颈。\n知识延伸：掌握基础知识点后，延伸拓展相关内容，丰富知识储备。\n答疑解惑：备考、工作中遇到的专业问题，及时获取清晰解答。",
            "深度讲解AR智能体的光学显示原理，拆解核心卡点，用通俗语言说明，举2个实际应用例子，延伸相关技术发展趋势。"
        ),
        (
            "每日研究简报",
            "漏掉重要论文和行业报告？每天帮你盯着，关键信息一条不漏",
            "科研学习：每日获取相关领域论文、报告，及时掌握行业研究动态。\n职场提升：关注行业前沿报告，补充专业知识，助力工作开展。\n学术积累：收集相关领域研究成果，为论文、汇报积累素材。",
            "设置每日「9:00」的自动定时任务，自动抓取“AR/VR领域”的最新论文和行业报告，提炼核心观点生成研究简报，推送到我的眼前。"
        ),
        (
            "科技资讯精选",
            "信息爆炸跟不上？每日精选科技热点，一文掌握行业动态",
            "碎片时间：通勤、休息时，快速查看科技资讯，丰富知识储备。\n职场适配：关注科技领域动态，助力工作中把握技术趋势。\n学习补充：了解科技前沿，为学习、科研提供新思路。",
            "每日推送“AI、AR/VR领域”的精选科技资讯，简洁提炼核心内容，支持语音朗读，每日更新10条。"
        ),
        (
            "懒人出游规划",
            "周末不知道去哪玩？直接喂到你嘴边",
            "周末出游：周末想出行，无需手动查攻略，一键获取完整规划。\n亲子出行：输入“亲子游”偏好，生成适合孩子的出游路线，兼顾趣味与便捷。\n短途旅行：短途出行前，快速获取精准规划，节省攻略时间。",
            "规划“周末2天北京亲子游”，偏好亲子景点、清淡餐饮，交通优先选择地铁，生成详细路线。"
        ),
        (
            "趣味塔罗小指引",
            "心中有小纠结？塔罗趣味抽牌，给你轻松小参考",
            "纠结选择：面临小选择时，获取趣味指引，缓解选择焦虑。\n休闲消遣：闲暇时抽牌，增添生活乐趣，打发碎片时间。\n心情调节：通过趣味指引，获得积极心理暗示，调节心情。",
            "我纠结“周末要不要去短途旅行”，触发塔罗抽牌，生成1张塔罗牌，给出趣味指引，语气轻松，不涉及封建迷信。"
        ),
        (
            "生辰趣味解读",
            "输入生辰，解锁传统命理文化趣味解读",
            "休闲娱乐：和朋友闲聊时，解读生辰，增添互动乐趣。\n自我消遣：闲暇时了解生辰趣味解读，打发时间，调节心情。\n人际互动：通过生辰解读，找到与他人的趣味共鸣点，拉近关系。",
            "输入我的生辰信息（1998年5月10日），给出趣味解读，内容轻松有趣，规避封建迷信表述，保护我的隐私。"
        ),
        (
            "MBTI 配对分析",
            "想知道合不合？帮你分析性格契合度",
            "人际交往：了解与朋友、同事的 MBTI 契合度，获取相处小建议。\n情感互动：分析与伴侣的 MBTI 配对情况，增进彼此理解。\n休闲趣味：和朋友一起分析 MBTI 配对，增添互动乐趣。",
            "我是INFJ，对方是ESTP，分析我们的性格契合度，给出客观温和的相处建议，仅作娱乐参考，不绝对化。"
        ),
        (
            "影视推荐小助手",
            "周末不知道看啥？按口味精准推荐，片源直接给到",
            "休闲放松：周末、休息时，想追剧/看电影，快速获取贴合偏好的推荐。\n口味匹配：输入“悬疑、豆瓣8分以上”等偏好，精准推荐，避免踩雷。\n发现新片：获取小众优质影视推荐，拓宽影视观看范围。",
            "推荐“豆瓣8分以上、悬疑类型”的影视，优先选择近两年上映的，提供合规观看指引，推荐10部并简要介绍剧情。"
        ),
        (
            "经济数据查询",
            "读懂 GDP、利率、CPI，把握市场关键参考",
            "职场参考：从事金融、商务相关工作，查询经济数据，为工作决策提供支撑。\n投资参考：了解利率、CPI 等数据，为个人投资提供参考。\n学习了解：学习经济相关知识，查询最新数据，加深理解。",
            "查询中国最新GDP数据、1年期LPR利率，给出通俗解读，对比上月数据，说明变化趋势，语音播报结果。"
        ),
        (
            "量化策略模拟回测",
            "策略靠不靠谱？用历史数据回测验证你的交易策略",
            "个人投资：输入自定义交易策略，通过历史数据回测，提前判断策略盈利潜力，避免实际操作亏损。\n策略优化：根据回测报告中的风险点、收益率数据，调整交易策略细节，提升实战成功率。\n学习实践：学习量化交易知识时，通过模拟回测实操演练，加深对交易策略的理解与应用。",
            "启动量化策略模拟回测，输入“均线交叉交易策略”（5日均线金叉买入、死叉卖出），用近1年的股票历史数据进行回测，生成简洁适配AR镜片的回测报告，重点展示收益率、风险系数，完成后推送至我的AR镜片。"
        )
    ]
}
