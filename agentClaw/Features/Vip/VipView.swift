import SwiftUI

struct VipView: View {
    @Binding var isPresented: Bool
    var onLoginRequired: (() -> Void)?

    @ObservedObject private var vm: VipViewModel

    init(isPresented: Binding<Bool>, onLoginRequired: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.onLoginRequired = onLoginRequired
        _vm = ObservedObject(wrappedValue: VipViewModel())
    }
    @State private var showAgreement = false
    @State private var showAgreementAlert = false
    @State private var showBenefitsDetail = false

    private let badgeTexts = ["限时特惠", "超值特惠", "80%用户选择"]
    private let badgeColors: [(String, String)] = [
        ("#9C27B0", "#6A1B9A"),
        ("#FFB300", "#F57C00"),
        ("#FF6B35", "#E53935")
    ]

    var body: some View {
        ZStack {
            Color(hex: "#0D0703").edgesIgnoringSafeArea(.all)
            topDecoration

            VStack(spacing: 0) {
                navigationBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        userInfoArea
                        benefitsCard
                        productsScrollView
                        statusText
                        payMethodDivider
                        payChannelArea
                        warmTips
                    }
                    .padding(.bottom, 18)
                }

                bottomBar
            }

            if let toast = vm.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(20)
                    Spacer().frame(height: 120)
                }
                .transition(.opacity)
            }

            if showAgreement, let url = URL(string: "https://www.cjym123.cn/agreement_agentclaw_vip.html") {
                InAppLegalWebView(
                    page: LegalWebPage(title: "会员服务协议", url: url),
                    onClose: { showAgreement = false }
                )
                .transition(.move(edge: .trailing))
                .zIndex(20)
            }

            if showBenefitsDetail {
                VipBenefitsDetailSheet(
                    products: vm.products,
                    selectedIndex: vm.selectedIndex,
                    memberActive: vm.memberActive,
                    onSelectProduct: { vm.selectProduct($0) },
                    onPurchase: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showBenefitsDetail = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            requestPayment()
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showBenefitsDetail = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(15)
            }
        }
        .sheet(isPresented: $vm.showLogin) {
            LoginView(onLoggedIn: { vm.loadData() })
        }
        .alert(isPresented: $showAgreementAlert) {
            Alert(
                title: Text("请同意服务协议"),
                message: Text("开通会员前，请先阅读并同意《会员服务协议》。"),
                primaryButton: .default(Text("同意并继续")) {
                    vm.isAgreementChecked = true
                    vm.startPayment()
                },
                secondaryButton: .default(Text("去查看")) {
                    withAnimation { showAgreement = true }
                }
            )
        }
        .onAppear { vm.loadData() }
    }

    private var topDecoration: some View {
        VStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#5B321D").opacity(0.72), Color(hex: "#241109").opacity(0.45), .clear],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                Circle()
                    .fill(Color(hex: "#C87830").opacity(0.12))
                    .frame(width: 230, height: 230)
                    .blur(radius: 28)
                    .offset(x: 110, y: -50)
            }
            .frame(height: 310)
            Spacer()
        }
        .edgesIgnoringSafeArea(.top)
        .allowsHitTesting(false)
    }

    // MARK: - Nav Bar

    private var navigationBar: some View {
        HStack {
            Button(action: { isPresented = false }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#FFEDBD"))
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text("VIP 会员")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#FFEDBD"))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(Color(hex: "#0D0703").opacity(0.74))
    }

    // MARK: - User Info

    private var userInfoArea: some View {
        HStack(spacing: 12) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#F3D49C"), Color(hex: "#8A4E2D")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(Circle())
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#FFF2D2"))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.isLoggedIn ? vm.maskedPhone : "登录后开通会员")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(vm.memberActive && vm.vipExpiresAt != nil
                     ? "尊贵会员 · 有效期至 \(vm.vipExpiresAt!)"
                     : "开通会员，解锁AI助手全部功能")
                    .font(.system(size: 13))
                    .foregroundColor(vm.memberActive ? Color(hex: "#FFEDBD") : Color(hex: "#CDAF7A"))
                    .lineLimit(1)
            }

            Spacer()

            if !vm.isLoggedIn {
                Button(action: { vm.showLogin = true }) {
                    Text("去登录")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#864F2D"))
                        .padding(.horizontal, 18)
                        .frame(height: 28)
                        .background(Color(hex: "#EECC9A"))
                        .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    // MARK: - Products

    private var productsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if vm.products.isEmpty {
                    placeholderCard
                } else {
                    ForEach(vm.products.indices, id: \.self) { index in
                        productCard(product: vm.products[index], index: index)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 164)
        .padding(.top, 24)
    }

    private var placeholderCard: some View {
        VStack {
            Text("会员套餐\n\n加载中…")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#9C8A75"))
                .multilineTextAlignment(.center)
        }
        .frame(width: 138, height: 148)
        .background(Color(hex: "#1A0D08"))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4A2D1A"), lineWidth: 1))
    }

    private func productCard(product: VipProduct, index: Int) -> some View {
        let isSelected = vm.selectedIndex == index
        let badgeText = badgeTexts.indices.contains(index) ? badgeTexts[index] : nil
        let badgeColor = badgeColors.indices.contains(index) ? badgeColors[index] : nil
        return VipProductCard(
            product: product,
            isSelected: isSelected,
            badgeText: badgeText,
            badgeColor: badgeColor,
            onTap: { vm.selectProduct(index) }
        )
    }

    // MARK: - Benefits Card (会员权益, matches Android bg_new_vip_right_back card)

    private var benefitsCard: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.2)) {
                showBenefitsDetail = true
            }
        }) {
            VStack(spacing: 16) {
                HStack {
                    Text("会员权益")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#FFEDBD"))
                    Spacer()
                    HStack(spacing: 3) {
                        Text("查看套餐详情")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#CDAF7A"))
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)

                HStack(spacing: 0) {
                    benefitItem(icon: "bubble.left.and.bubble.right.fill", title: "无限对话")
                    benefitItem(icon: "star.fill", title: "专属功能")
                    benefitItem(icon: "bolt.fill", title: "优先体验")
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#1A0D08"), Color(hex: "#2D1A10"), Color(hex: "#3B2518")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 13)
        .padding(.top, 12)
    }

    private var statusText: some View {
        Text(vm.statusMessage)
            .font(.system(size: 12))
            .foregroundColor(Color(hex: "#999999"))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }

    private func benefitItem(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "#FFEDBD"))
                .frame(width: 36, height: 36)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pay Method Divider

    private var payMethodDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color(hex: "#DCDCDC"))
                .frame(width: 20, height: 1)
            Text("支付方式")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#999999"))
            Rectangle()
                .fill(Color(hex: "#DCDCDC"))
                .frame(width: 20, height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    // MARK: - Pay Channel (only Alipay, matches Android - WeChat is visibility=gone)

    private var payChannelArea: some View {
        payChannelButton(channel: "alipay", icon: "a.circle.fill", title: "支付宝支付")
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }

    private func payChannelButton(channel: String, icon: String, title: String) -> some View {
        let isSelected = vm.selectedChannel == channel
        return Button(action: { vm.selectedChannel = channel }) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#864F2D") : Color(hex: "#FEEBB9"))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#864F2D") : Color(hex: "#FEEBB9"))
                }
                .frame(maxWidth: .infinity, minHeight: 56)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color(hex: "#C87830"))
                        .cornerRadius(7, corners: [.bottomLeft])
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isSelected ? Color(hex: "#FEEBB9") : Color(hex: "#2A292D"))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                isSelected ? Color(hex: "#C87830") : Color(hex: "#4A2D1A"), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var warmTips: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("温馨提示")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#999999"))
            Text("1. 会员服务开通后立即生效。\n2. 支付完成后以服务端订单状态为准。\n3. 如遇支付异常，请稍后重新进入会员页查看。")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#666666"))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Button(action: requestPayment) {
                ZStack {
                    if vm.isLoading {
                        ActivityIndicator(isAnimating: .constant(true), style: .medium)
                    } else {
                        HStack(spacing: 8) {
                            Text(vm.displayPrice.replacingOccurrences(of: "¥", with: "￥"))
                                .font(.system(size: 24, weight: .bold))
                            Text(vm.memberActive ? "立即续费" : "立即开通")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#864F2D"))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    LinearGradient(
                        colors: vm.isPayEnabled
                            ? [Color(hex: "#FEEBB9"), Color(hex: "#FFD889")]
                            : [Color(hex: "#4B4137"), Color(hex: "#38312B")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(24)
            }
            .disabled(!vm.isPayEnabled || vm.isLoading)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 28)
            .padding(.top, 7)

            HStack(spacing: 2) {
                Button(action: { vm.isAgreementChecked.toggle() }) {
                    Image(systemName: vm.isAgreementChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(vm.isAgreementChecked ? Color(hex: "#C87830") : Color(hex: "#77706A"))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                Text("请阅读并同意")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#999999"))
                Button(action: { withAnimation { showAgreement = true } }) {
                    Text("《会员服务协议》")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#C87830"))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .background(Color(hex: "#0D0703"))
    }

    private func requestPayment() {
        if vm.isAgreementChecked {
            vm.startPayment()
        } else {
            showAgreementAlert = true
        }
    }
}

// MARK: - Benefits and Package Detail Sheet

private struct VipBenefitsDetailSheet: View {
    let products: [VipProduct]
    let selectedIndex: Int?
    let memberActive: Bool
    let onSelectProduct: (Int) -> Void
    let onPurchase: () -> Void
    let onDismiss: () -> Void

    private let quota = QuotaManager.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.58)
                    .edgesIgnoringSafeArea(.all)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)

                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color(hex: "#6A513B"))
                        .frame(width: 38, height: 4)
                        .padding(.top, 10)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(Color(hex: "#F6D28F"))
                                Text("会员套餐详情")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFEDBD"))
                            }
                            Text("开通会员，解锁更多 AI 创作能力")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#A89178"))
                        }
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#D8C3A5"))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            quotaComparison
                            detailedBenefits
                            packageSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                    }

                    purchaseBar
                }
                .frame(maxWidth: .infinity)
                .frame(height: min(proxy.size.height * 0.82, 680))
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#24150C"), Color(hex: "#110A06")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: -8)
                .onTapGesture { }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }

    private var quotaComparison: some View {
        HStack(spacing: 10) {
            quotaCard(
                icon: "photo.fill",
                title: "图片生成",
                free: "\(quota.freeImageLimit()) 张/天",
                vip: "\(quota.vipImageLimit()) 张/天"
            )
            quotaCard(
                icon: "video.fill",
                title: "视频生成",
                free: "\(quota.freeVideoLimit()) 次/天",
                vip: "\(quota.vipVideoLimit()) 次/天"
            )
        }
    }

    private func quotaCard(icon: String, title: String, free: String, vip: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(hex: "#F2D39B"))

            HStack {
                Text("普通用户")
                Spacer()
                Text(free)
            }
            .font(.system(size: 11))
            .foregroundColor(Color(hex: "#837568"))

            HStack {
                Text("VIP 会员")
                Spacer()
                Text(vip)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Color(hex: "#F6D28F"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(Color(hex: "#2A1B12"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#503722"), lineWidth: 1))
    }

    private var detailedBenefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全部会员权益")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "#FFEDBD"))

            HStack(spacing: 8) {
                detailBenefit(icon: "bubble.left.and.bubble.right.fill", title: "畅享对话", detail: "更充足的 AI 对话服务")
                detailBenefit(icon: "wand.and.stars", title: "AI 创作", detail: "提升图片与视频生成额度")
                detailBenefit(icon: "bolt.fill", title: "优先体验", detail: "新能力与专属功能优先使用")
            }
        }
    }

    private func detailBenefit(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "#F6D28F"))
                .frame(height: 26)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#988571"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 112)
        .background(Color.white.opacity(0.045))
        .cornerRadius(12)
    }

    private var packageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择会员套餐")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "#FFEDBD"))

            if products.isEmpty {
                HStack(spacing: 8) {
                    CompatProgressView()
                    Text("正在加载套餐…")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#988571"))
                }
                .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                ForEach(products.indices, id: \.self) { index in
                    packageRow(product: products[index], index: index)
                }
            }
        }
    }

    private func packageRow(product: VipProduct, index: Int) -> some View {
        let selected = selectedIndex == index
        return Button(action: { onSelectProduct(index) }) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selected ? Color(hex: "#E6B765") : Color(hex: "#6E5C4B"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(selected ? Color(hex: "#FFEDBD") : .white)
                    if !product.description.isEmpty {
                        Text(product.description)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#988571"))
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text("￥\(product.price)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#F6D28F"))
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(selected ? Color(hex: "#3A291B") : Color(hex: "#21160F"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color(hex: "#D3A85F") : Color(hex: "#483322"), lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var purchaseBar: some View {
        VStack(spacing: 8) {
            Button(action: onPurchase) {
                HStack(spacing: 8) {
                    if let selectedIndex = selectedIndex, products.indices.contains(selectedIndex) {
                        Text("￥\(products[selectedIndex].price)")
                            .font(.system(size: 20, weight: .bold))
                    }
                    Text(memberActive ? "立即续费" : "立即开通会员")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(Color(hex: "#75451F"))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FEEBB9"), Color(hex: "#FFD889")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(24)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectedIndex == nil || products.isEmpty)
            .opacity(selectedIndex == nil || products.isEmpty ? 0.5 : 1)

            Text("开通前请阅读并同意页面下方《会员服务协议》")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#756757"))
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Color(hex: "#110A06"))
    }
}

// MARK: - VipProductCard

struct VipProductCard: View {
    let product: VipProduct
    let isSelected: Bool
    let badgeText: String?
    let badgeColor: (String, String)?
    let onTap: () -> Void

    private var priceColor: Color { isSelected ? Color(hex: "#864F2D") : Color(hex: "#EBC783") }
    private var nameColor: Color  { isSelected ? Color(hex: "#6B3820") : Color(hex: "#B6A58E") }
    private var descColor: Color  { isSelected ? Color(hex: "#9B5C38") : Color(hex: "#7A6B58") }
    private var borderColor: Color { isSelected ? Color(hex: "#EBC783") : Color(hex: "#514437") }
    private var borderWidth: CGFloat { isSelected ? 2 : 1 }

    var body: some View {
        ZStack(alignment: .top) {
            cardBody
            if let badge = badgeText, let colors = badgeColor {
                badgeView(text: badge, colors: colors)
            }
        }
        .frame(height: 164)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var cardBody: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: badgeText != nil ? 14 : 4)
            Text("¥\(product.price)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(priceColor)
            Text(product.name)
                .font(.system(size: 12))
                .foregroundColor(nameColor)
            if !product.description.isEmpty {
                Text(product.description)
                    .font(.system(size: 10))
                    .foregroundColor(descColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
            Spacer()
        }
        .frame(width: 138, height: 148)
        .background(
            LinearGradient(
                colors: isSelected
                    ? [Color(hex: "#493522"), Color(hex: "#2B2118")]
                    : [Color(hex: "#1A1512"), Color(hex: "#1A1512")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: borderWidth))
        .padding(.top, 16)
    }

    private func badgeView(text: String, colors: (String, String)) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [Color(hex: colors.0), Color(hex: colors.1)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(10)
            .offset(y: 4)
    }
}

extension View {
    @ViewBuilder
    func vipFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if #available(iOS 14.0, *) {
            fullScreenCover(isPresented: isPresented, content: content)
        } else {
            sheet(isPresented: isPresented, content: content)
        }
    }
}
