import SwiftUI

struct SettingsPanelView: View {
    enum Page {
        case skills
        case about
    }

    @ObservedObject var gatewayViewModel: GatewayConnectionViewModel
    @Binding var isPresented: Bool
    @State private var selectedPage: Page = .skills
    @State private var skillQuery = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let skills = [
        SkillItem(name: "PDF", detail: "PDF 表单识别、图片转换、字段提取", enabled: true),
        SkillItem(name: "PPTX", detail: "演示文稿生成、页面编辑、缩略图", enabled: true),
        SkillItem(name: "HTML Default", detail: "Markdown 到 HTML 的基础转换", enabled: true),
        SkillItem(name: "Multi Search Engine", detail: "多搜索源查询与整理", enabled: false)
    ]

    var body: some View {
        GeometryReader { proxy in
            let isCompact = horizontalSizeClass == .compact || proxy.size.width < 560
            let dialogHeight = isCompact ? proxy.size.height * 0.52 : min(proxy.size.height * 0.62, 500)

            ZStack {
                Color.black.opacity(0.18).edgesIgnoringSafeArea(.all)

                settingsPanel(isCompact: isCompact)
                    .padding(10)
                    .frame(maxWidth: isCompact ? proxy.size.width - 20 : 760)
                    .frame(height: max(dialogHeight, isCompact ? 320 : 420))
                    .background(settingLeftBackground)
                    .cornerRadius(14)
                    .padding(isCompact ? 8 : 24)
            }
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("设置")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 40)

            menuButton(page: .skills, imageName: "list_skill", title: "技能管理")
            menuButton(page: .about, imageName: "list_about", title: "关于我们")

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(settingLeftBackground)
    }

    @ViewBuilder
    private func settingsPanel(isCompact: Bool) -> some View {
        if isCompact {
            VStack(spacing: 0) {
                compactHeader
                    .padding(.bottom, 8)

                HStack(spacing: 6) {
                    menuButton(page: .skills, imageName: "list_skill", title: "技能")
                    menuButton(page: .about, imageName: "list_about", title: "关于")
                }
                .padding(.bottom, 8)

                content(isCompact: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            HStack(spacing: 10) {
                menu
                    .frame(width: 200)

                content(isCompact: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var compactHeader: some View {
        HStack {
            Text("设置")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func content(isCompact: Bool) -> some View {
        Group {
            switch selectedPage {
            case .skills:
                skillsPage
            case .about:
                aboutPage
            }
        }
        .padding(isCompact ? 12 : 20)
        .background(settingRightBackground)
        .cornerRadius(12)
    }

    private var skillsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            pageHeader(title: "技能管理", subtitle: "扩展智能体的能力：一键集成精选技能与工具")

            HStack(spacing: 10) {
                HStack {
                    Image("icon_search")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    TextField("搜索技能", text: $skillQuery)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color.white.opacity(0.88))
                .cornerRadius(8)

                Button(action: {}) {
                    Text("添加技能")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 74, height: 40)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }

            ScrollView {
                skillGrid
                    .padding(.bottom, 4)
            }
        }
    }

    private var skillGrid: some View {
        VStack(spacing: 10) {
            ForEach(skillRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 10) {
                    ForEach(skillRows[rowIndex]) { skill in
                        skillCard(skill)
                    }

                    if skillRows[rowIndex].count == 1 {
                        Spacer()
                    }
                }
            }
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关于我们")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))

            VStack(spacing: 4) {
                Image("about_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 76)
                Text("Agent Claw")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)

            VStack(spacing: 8) {
                aboutListRow(title: "当前版本", detail: "V-")
                aboutListRow(title: "用户协议")
                aboutListRow(title: "隐私政策")
            }
            .padding(.top, 4)

            Spacer()
        }
    }

    private var filteredSkills: [SkillItem] {
        let query = skillQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return skills
        }
        return skills.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
                $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

    private var skillRows: [[SkillItem]] {
        stride(from: 0, to: filteredSkills.count, by: 2).map { index in
            Array(filteredSkills[index..<min(index + 2, filteredSkills.count)])
        }
    }

    private func menuButton(page: Page, imageName: String, title: String) -> some View {
        Button(action: { selectedPage = page }) {
            HStack(spacing: 10) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.system(size: 14, weight: selectedPage == page ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
            }
            .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(selectedPage == page ? Color.white.opacity(0.72) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(AgentClawDesign.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func skillCard(_ skill: SkillItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image("icon_skill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 30)

                Text(skill.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .lineLimit(1)

                Spacer()

                Image("icon_remove")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }

            Text(skill.detail)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.40, green: 0.40, blue: 0.40))
                .lineLimit(2)
                .padding(.leading, 33)

            Divider().background(Color(red: 0.93, green: 0.93, blue: 0.93))

            HStack {
                Text("内置技能")
                    .font(.system(size: 10))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color(red: 0.95, green: 0.96, blue: 0.98))
                    .cornerRadius(6)
                Spacer()
                Image(skill.enabled ? "switch_on" : "switch_off")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 14)
            }
        }
        .padding(14)
        .frame(minHeight: 130, alignment: .topLeading)
        .background(Color.white)
        .cornerRadius(12)
    }

    private func aboutListRow(title: String, detail: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            if let detail = detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.60, green: 0.60, blue: 0.60))
            }
            Spacer()
            if detail == nil {
                Image("arrow_right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color.white)
        .cornerRadius(8)
    }

    private var settingLeftBackground: Color {
        Color(red: 0.96, green: 0.97, blue: 0.98)
    }

    private var settingRightBackground: Color {
        Color(red: 0.98, green: 0.985, blue: 0.99)
    }
}

private struct SkillItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let enabled: Bool
}
