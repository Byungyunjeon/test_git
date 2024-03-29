/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Vision view controller.
			Recognizes text using a Vision VNRecognizeTextRequest request handler in pixel buffers from an AVCaptureOutput.
			Displays bounding boxes around recognized text results in real time.
*/

import Foundation
import UIKit
import AVFoundation
import Vision

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}
extension String {
    subscript(_ range: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
        let end = index(start, offsetBy: min(self.count - range.lowerBound,
                                             range.upperBound - range.lowerBound))
        return String(self[start..<end])
    }

    subscript(_ range: CountablePartialRangeFrom<Int>) -> String {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
         return String(self[start...])
    }
}

extension Array {
    var middle: Element? {
        guard count != 0 else { return nil }
        let middleIndex = (count > 1 ? count - 1 : count) / 2
        return self[middleIndex]
    }}

class VisionViewController: ViewController {
	var request: VNRecognizeTextRequest!
	// Temporal string tracker
	let numberTracker = StringTracker()
    var detectedRecordDic: [String: [String: [String]]] = [:]
    var detectedRecordArray: Dictionary<String, Dictionary<String, String>> = [:]
    var detectedRecords: Array<String> = []
    // Variables for cattle API
    @IBOutlet weak var resultCode, resultMsg, abattCode, birthYmd, butcheryPlaceAddr, butcheryPlaceNm, butcheryWeight, butcheryYmd, cattleNo, farmAddr, farmNm, farmNo, inspectPassNm, lsTypeCd, lsTypeNm, processPlaceNm, qgradeNm, sexCd, sexNm, vaccineLastinjectionOrder, vaccineLastinjectionYmd: UILabel!
    // additional variables for traceNoSerach API
    @IBOutlet weak var lotNo, infoType, corpNo, gradeNm, traceNoType, insfat, processPlaceAddr: UILabel!
    // Variables for self computation
    @IBOutlet weak var daysFromButchery, monthsFromBirth, serviceNotices, animalAge, butcheryAge, itemGroup, cattleNoUp, numGroup: UILabel!
    
    let urlSet: Dictionary<String, Dictionary<String, String>> = [ "urlSeoul": ["url": "https://k39frltac3.execute-api.ap-northeast-2.amazonaws.com/deploy_20_06_36/resource_20_06_33", "name": "id", "key" :  "7IQCjMsvO76QYjHO2vdUq6fUZJrdieze9FhT5uzQ", "check": "v7*T@igerlR8R057MyCtHxjGqdGwZ&upF3BC30xhCP^D7KiiD0", "checkv": "5S6y9%7%RbFKuN6o8#q5Cvh4kM2VD5jD79Znedr*$AUevjH$r@" ] ]
    
	override func viewDidLoad() {
		// Set up vision request before letting ViewController set up the camera
		// so that it exists when the first buffer is received.
		request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
		super.viewDidLoad()
	}
    // clear text in view screen.
    func clearIBOtext() {
        DispatchQueue.main.async {
            for name in [self.cattleNo, self.lsTypeNm, self.sexNm, self.monthsFromBirth, self.butcheryWeight, self.qgradeNm, self.butcheryYmd, self.daysFromButchery, self.butcheryPlaceNm, self.processPlaceNm, self.serviceNotices, self.animalAge, self.butcheryAge, self.itemGroup, self.cattleNoUp, self.numGroup] {
                name!.text = ""
            }
        }
    }
    func waitingNotify() {
        DispatchQueue.main.async {
            let detectedRecord = self.detectedRecords[self.detectedRecords.count-1]
            let sini = detectedRecord[0..<1]
            self.cattleNo.text = "감지된 이력번호: " + detectedRecord
            if self.detectedRecordArray.keys.contains(detectedRecord) == false {
                if sini == "L" {
                    self.serviceNotices.text = "이력번호 감지되었습니다. 묶음번호 초기 조회 중.\n인터넷 지연시간에 따라 몇 초에서 몇 십초 정도 걸려요."
                } else {
                    self.serviceNotices.text = "이력번호 감지되었습니다.\n...초기 조회 중...\n인터넷 지연시간에 따라 몇 초에서 몇 십초 정도 걸려요."
                }
            } else {
                self.serviceNotices.text = "...조회 중..."
            }
        }
    }
    func arrAverage(_ arr: Array<Int>) -> Int {
        var sum = 0
        for i in arr { sum += i }
        return sum/arr.count
    }
    func dicSummary(_ dic: Dictionary<String, Dictionary<String, String>>) -> String {
        var ageArr: Array<Int> = []
        var butArr: Array<Int> = []
        for key in dic.keys {
            // ! would make Fatal error. later ! should be removed after bug fixs.
            ageArr.append(Int(dic[key]!["birthYmd"]!)!)
            butArr.append(Int(dic[key]!["butcheryYmd"]!)!)
        }
        return "월령: 최저 " + String(ageArr.min()!) + "개월, " + "최고 " + String(ageArr.max()!) + "개월, " + "평균 " //+ String(self.ageArr.middle!) + "개월\n" + "도축일: 최저 " + String(butArr.min()!) + "일, " + "최고 " + String(butArr.max()!) + "일, " + "평균 " + String(self.butArr.middle!) + "일\n"
    }
    //
    func dicString(_ dic: Dictionary<String, Dictionary<String, String>>) -> String {
        var keyAge: Dictionary<String, String> = [:]
        for key in dic.keys { keyAge[key] = dic[key]!["birthYmd"] }
        var keyAgeSorted: Array<String> = []
        for ituple in keyAge.sorted(by: { $0.value > $1.value }) {
            keyAgeSorted.append(ituple.key)
        } // sorting done.
        let nameArray = ["vaccineLastinjectionOrder", "sexNm", "birthYmd", "butcheryYmd", "butcheryPlaceNm", "qgradeNm", "processPlaceNm", "farmAddr", "inspectPassNm"]
        var oString = ""
        for key in keyAgeSorted {
            let iDic = dic[key]
            for name in nameArray {
                if name == "butcheryYmd" && iDic![name] != nil { oString += iDic![name]! + "일 "}
                else if name == "birthYmd" && iDic![name] != nil { oString += iDic![name]! + "개월 "}
                else if iDic![name] != nil { oString += iDic![name]! + " " }
            }
            oString += "\n"
        }
        return oString
    }
    //
    func birthAge(birthYmd: String, butcheryYmd: String) -> String {
        return self.daysBetweenDate(startDate: birthYmd, endDate: butcheryYmd, unit: "month")
    }
    //
    func cattleGroupStatic(_ cattleNoArray: Array<String>) -> Dictionary<String, Dictionary<String, String>> {
        var oDic: Dictionary<String, Dictionary<String, String>> = [:]
        for cattleNo in cattleNoArray {
            if detectedRecordArray[cattleNo] == nil { continue }
            let ArrayInfo = detectedRecordArray[cattleNo]
            let dicInfo = ArrayInfo!
            var iDic: Dictionary<String, String> = [:]
            for name in ["vaccineLastinjectionOrder", "sexNm", "birthYmd", "butcheryYmd", "butcheryPlaceNm", "qgradeNm", "processPlaceNm", "farmAddr", "inspectPassNm"] {
                var text = ""
                if dicInfo[name] == nil {
                    iDic[name] = "없음"
                    continue
                }
                if "vaccineLastinjectionOrder" == name {
                    text = dicInfo[name]!.replacingOccurrences(of: " ", with: "")
                    if text.count == 2 { text = "=" + text }
                } else if "sexNm" == name {
                    text = dicInfo[name]!
                    if text.count == 1 { text += "소" }
                } else if "birthYmd" == name && dicInfo["butcheryYmd"] != nil {
                    text = birthAge(birthYmd: dicInfo["birthYmd"]!, butcheryYmd: dicInfo["butcheryYmd"]!)
                } else if "butcheryYmd" == name {
                    text = self.daysBetweenDate(startDate: dicInfo["butcheryYmd"]!, endDate: "today", unit: "")
                } else if "butcheryPlaceNm" == name {
                    text = dicInfo["butcheryPlaceNm"]!.replacingOccurrences(of: "농협", with: "").replacingOccurrences(of: "주식", with: "").replacingOccurrences(of: "농업", with: "").replacingOccurrences(of: "법인", with: "").replacingOccurrences(of: "회사", with: "").replacingOccurrences(of: "㈜", with: "").replacingOccurrences(of: "축산", with: "").replacingOccurrences(of: " ", with: "")[0..<2]
                } else if "qgradeNm" == name {
                    text = dicInfo["qgradeNm"]!
                    let tc = text.count
                    if tc == 2 { text += "=" }
                    else if tc == 1 { text += "==" }
                } else if "processPlaceNm" == name {
                    text = dicInfo["processPlaceNm"]!.replacingOccurrences(of: "농협", with: "").replacingOccurrences(of: "주식", with: "").replacingOccurrences(of: "농업", with: "").replacingOccurrences(of: "법인", with: "").replacingOccurrences(of: "회사", with: "").replacingOccurrences(of: "축산", with: "").replacingOccurrences(of: "㈜", with: "").replacingOccurrences(of: " ", with: "")[0..<2]
                } else if "farmAddr" == name {
                    text = String(dicInfo["farmAddr"]!.split(separator: " ")[1])[0..<2]
                } else if "inspectPassNm" == name {
                    if dicInfo["inspectPassNm"] == "합격" {
                        text = "O"
                    } else {
                        text = "X"
                    }
                }
                iDic[name] = text
            }
            oDic[cattleNo] = iDic
        }
        return oDic
    }
    //
    func nowTime() -> String {
        let today = Date()
        let formatter2 = DateFormatter()
        formatter2.timeStyle = .medium
        let now = formatter2.string(from: today)
        return now
    }
        
    var stringInfoLot: Dictionary<String, String> = [:]
    func textLoadCattleSubs(_ lotNo: String) {
        if self.stringInfoLot[lotNo] != nil {
            let st = self.stringInfoLot[lotNo]
            DispatchQueue.main.async {
                self.numGroup.text = String(st!.components(separatedBy: "O").count-1) + "묶음"
                self.itemGroup.text = st!
            }
        }
    }
    
    func arrSummary(_ cattleNoArray: Array<String>) -> String {
        var ageArr: Array<Int> = []
        var butArr: Array<Int> = []
        for cattleNo in cattleNoArray {
            let dicInfo = detectedRecordArray[cattleNo]!
            // ! would make Fatal error. later ! should be removed after bug fixs.
            ageArr.append(Int(dicInfo["birthYmd"]!)!)
            butArr.append(Int(dicInfo["butcheryYmd"]!)!)
        }
        return "--------------------------------------------\n" + "월령: 최저 " + String(ageArr.min()!) + "개월, " + "최고 " + String(ageArr.max()!) + "개월, " + "중간값 " + String(self.arrAverage(ageArr)) + "개월\n" + "도축일: 최저 " + String(butArr.min()!) + "일, " + "최고 " + String(butArr.max()!) + "일, " + "중간값 " + String(self.arrAverage(butArr)) + "일\n"
    }
    
    func textLoadCattleSub(_ cattleNo: String) -> String {
        let dicInfo = detectedRecordArray[cattleNo]!
        let nameArray = ["vaccineLastinjectionOrder", "sexNm", "birthYmd", "butcheryYmd", "butcheryPlaceNm", "qgradeNm", "processPlaceNm", "farmAddr", "inspectPassNm"]
        var text = ""
        for name in nameArray {
            if dicInfo[name] == nil {
                text += "없음 "
                continue
            }
            if "vaccineLastinjectionOrder" == name {
                let to = dicInfo[name]!.replacingOccurrences(of: " ", with: "")
                if to.count == 2 { text += "=" + to }
                else { text += to }
            } else if "sexNm" == name {
                let to = dicInfo[name]!
                if to.count == 1 { text += to + "소" }
                else { text += to }
            } else if "birthYmd" == name && dicInfo["butcheryYmd"] != nil {
                text += birthAge(birthYmd: dicInfo["birthYmd"]!, butcheryYmd: dicInfo["butcheryYmd"]!) + "개월"
            } else if "butcheryYmd" == name {
                text += self.daysBetweenDate(startDate: dicInfo["butcheryYmd"]!, endDate: "today", unit: "")  + "일"
            } else if "butcheryPlaceNm" == name {
                text += dicInfo["butcheryPlaceNm"]!.replacingOccurrences(of: "농협", with: "").replacingOccurrences(of: "주식", with: "").replacingOccurrences(of: "농업", with: "").replacingOccurrences(of: "법인", with: "").replacingOccurrences(of: "회사", with: "").replacingOccurrences(of: "㈜", with: "").replacingOccurrences(of: "(주)", with: "").replacingOccurrences(of: "축산", with: "").replacingOccurrences(of: " ", with: "")[0..<2]
            } else if "qgradeNm" == name {
                let to = dicInfo["qgradeNm"]!
                let tc = to.count
                if tc == 2 { text += to + "=" }
                else if tc == 1 { text += to + "==" }
                else { text += to }
            } else if "processPlaceNm" == name {
                let tos = dicInfo["processPlaceNm"]!.split(separator: "(")[0]
                text += tos.replacingOccurrences(of: "농협", with: "").replacingOccurrences(of: "주식", with: "").replacingOccurrences(of: "농업", with: "").replacingOccurrences(of: "법인", with: "").replacingOccurrences(of: "회사", with: "").replacingOccurrences(of: "축산", with: "").replacingOccurrences(of: "㈜", with: "").replacingOccurrences(of: "(주)", with: "").replacingOccurrences(of: " ", with: "")[0..<2]
            } else if "farmAddr" == name {
                text += String(dicInfo["farmAddr"]!.split(separator: " ")[1])[0..<2]
            } else if "inspectPassNm" == name {
                if dicInfo["inspectPassNm"] == "합격" {
                    text += "O"
                } else {
                    text += "X"
                }
            }
            text += " "
        }
        return text + "\n"
    }

    //for cattle API
    func textLoadCattleLot(_ cattleNoArray: Array<String>) {
        DispatchQueue.main.async {
            let stat = self.cattleGroupStatic(cattleNoArray)
            self.itemGroup.text = self.dicSummary(stat) + "백신 한우 월령 도축경과 도축 등급 포장 농장 합격\n" + self.dicString(stat)
        }
    }

    //
    func apiLoadAsyncArr(_ cattleNoArray: Array<String>, lotNo: String) {
        DispatchQueue.main.async {
            self.numGroup.text = String(cattleNoArray.count) + "묶음"
            self.itemGroup.text = "... 묶음구성내역 조회 중..."
        }
        let group = DispatchGroup()
        let keySet = detectedRecordArray.keys
        var stringArr: Array<String> = []
        for number in cattleNoArray {
            if keySet.contains(number) == true {
                let text = self.textLoadCattleSub(number)
                stringArr.append(text)
                // Now writing summary
                var oString = ""
                oString += "백신 소 월령 도축경과 도축장 등급 포장 농장 합격\n"
                for s in stringArr.reversed() { oString += s }
                oString += "\n ... 묶음구성내역 조회 중...\n"
                DispatchQueue.main.async {
                    self.itemGroup.text = oString
                }
                continue
            }
            group.enter()
            apiLoadCompletion(number) { (result) in
                switch result {
                case .success(let data):
                    DispatchQueue.main.async {
                        do {
                            if let preJson = try! JSONDecoder().decode(bodyJson.self, from: data).body.data(using: .utf8) {
                                if let jsonArray = try JSONSerialization.jsonObject(with: preJson, options : .allowFragments) as? Dictionary<String, String> {
                                    self.detectedRecordArray[number] = jsonArray
                                    let text = self.textLoadCattleSub(number)
                                    stringArr.append(text)
                                    // Now writing summary
                                    var oString = ""
                                    oString += "백신 소 월령 도축경과 도축장 등급 포장 농장 합격\n"
                                    for s in stringArr.reversed() { oString += s }
                                    oString += "\n ... 묶음구성내역 조회 중...\n"
                                    self.itemGroup.text = oString
                                    group.leave() // 1.
                                } else {
                                    print("bad json")
                                    group.leave() // 2.
                                }
                            } else {
                                print("bad preJson")
                                group.leave() // 2.5
                            }
                        } catch let error as NSError {
                            print(error)
                            group.leave() // 3.
                        }
                    }
                case .failure(let error):
                    print(error)
                    group.leave() // 4.
                }
            }
        }
        group.notify(queue: .main) {
            var oString = ""
            oString += self.textLoadCattleSum(cattleNoArray)
            oString += "백신 소 월령 도축경과 도축장 등급 포장 농장 합격\n"
            for s in stringArr.reversed() { oString += s }
            self.stringInfoLot[lotNo] = oString
            DispatchQueue.main.async {
                self.itemGroup.text = oString
            }
        }
    }
    
    func textLoadCattleSum(_ cattleNoArray: Array<String>) -> String {
        var ageArr: Array<Int> = []
        var butArr: Array<Int> = []
        for cattleNo in cattleNoArray {
            if nil != detectedRecordArray[cattleNo] {
                let dicInfo = detectedRecordArray[cattleNo]!
                if nil != dicInfo["birthYmd"] {
                    let so = birthAge(birthYmd: dicInfo["birthYmd"]!, butcheryYmd: dicInfo["butcheryYmd"]!)
                    if nil != Int(so) {
                        ageArr.append(Int(so)!)
                    }
                }
                if nil != dicInfo["butcheryYmd"] {
                    let si = self.daysBetweenDate(startDate: dicInfo["butcheryYmd"]!, endDate: "today", unit: "")
                    if nil != Int(si) {
                        butArr.append(Int(si)!)
                    }
                }
            }
        }
        ageArr = ageArr.sorted(by: { $0 > $1 })
        butArr = butArr.sorted(by: { $0 > $1 })
        var o: String = "월령: "
        guard let o1 = ageArr.min() else { return "" }
        o += "최저 " + String(o1) + "개월, "
        guard let o2 = ageArr.max() else { return o }
        o += "최고 " + String(o2) + "개월, "
        guard let o3 = ageArr.middle else { return o }
        o += "중간값 " + String(o3) + "개월\n"
//
        o += "도축: "
        guard let o4 = butArr.min() else { return o }
        o += "최저 " + String(o4) + "일, "
        guard let o5 = butArr.max() else { return o }
        o += "최고 " + String(o5) + "일, "
        guard let o6 = butArr.middle else { return o }
        o += "중간값 " + String(o6) + "일\n"
        return o
    }

	//for cattle API
    func textLoadCattle(_ detectedRecord: String) {
        DispatchQueue.main.async {
            self.serviceNotices.text = "이력번호를 감지했습니다.\n잠시만 기다려주세요..."
            self.cattleNo.text = "감지된 이력번호: " + detectedRecord
        }
        guard let dicInfo = self.detectedRecordArray[detectedRecord] else {
            DispatchQueue.main.async {
            self.serviceNotices.text = "이력번호를 잘못 감지했거나 전산에 등록되지 않은 이력번호인 것 같습니다."
                self.cattleNo.text = "감지된 이력번호: " + detectedRecord }
            print("error: No detectedRecord index in detectedRecordArray.")
            return
        }
        guard dicInfo["error"] == nil else {
            DispatchQueue.main.async {
            self.serviceNotices.text = "이력번호를 잘못 감지했거나 전산에 등록되지 않은 이력번호인 것 같습니다."
                self.cattleNo.text = "감지된 이력번호: " + detectedRecord }
            print("error is not nil.")
            return
        }
        var butcheryYmd = ""
        let sini = detectedRecord[0..<1]
        if sini == "L" {
            DispatchQueue.main.async {
                self.serviceNotices.text = self.nowTime()
                self.cattleNoUp.text = "이력번호: " + detectedRecord
                self.cattleNo.text = ""
                if dicInfo["processPlaceNm"] != nil {
                    self.lsTypeNm.text = "묶음: " + dicInfo["processPlaceNm"]!
                } else { self.lsTypeNm.text = "묶음 정보 없음." }
                self.itemGroup.text = "... 세부 정보 조회 중 ..."
            }
            return
        }
        if dicInfo["butcheryYmd"] != nil { butcheryYmd = dicInfo["butcheryYmd"]! }
        DispatchQueue.main.async {
            if butcheryYmd == "" {
                self.serviceNotices.text = "이력번호를 잘못 감지한 것 같아요.\n아니면 살아있거나 폐사하여 도축 정보가 없는 것 같습니다. 감지된 이력번호가 실제 이력번호와 같나요? 이력번호는 조회되지만 도축 정보가 없습니다."
                self.cattleNo.text = "감지된 이력번호: " + detectedRecord
                if dicInfo["sexNm"] != nil {
                    let sexNm = dicInfo["sexNm"]!
                    if sexNm == "암" {
                        self.sexNm.text = sexNm + "소"
                    } else if sexNm == "거세" {
                        self.sexNm.text = sexNm + "우"
                    } else {
                        self.sexNm.text = sexNm
                    }
                }
                if dicInfo["birthYmd"] != nil {
                    let birthYmd = dicInfo["birthYmd"]!
                    self.monthsFromBirth.text = "출생: " + self.dateReadingForm(birthYmd)
                }
                if dicInfo["farmAddr"] != nil { self.daysFromButchery.text = "농장: " + dicInfo["farmAddr"]! }
                self.butcheryYmd.text = "도축 정보 없음."
            } else {
                if Int(self.daysBetweenDate(startDate: butcheryYmd, endDate: "today", unit: "month"))! >= 6 {
                    self.serviceNotices.text = "이력번호를 잘못 감지한 것 같아요.\n아니면 도축한 지 6개월 이상된 것 같습니다.\n감지된 이력번호가 실제 이력번호와 같나요?"
                    self.cattleNo.text = "감지된 이력번호: " + detectedRecord
                } else {
                    let today = Date()
                    let formatter2 = DateFormatter()
                    formatter2.timeStyle = .medium
                    let now = formatter2.string(from: today)
                    self.serviceNotices.text = now
                    self.cattleNo.text = "이력번호: " + detectedRecord
                }
                if dicInfo["vaccineLastinjectionOrder"] != nil { self.lsTypeNm.text = dicInfo["vaccineLastinjectionOrder"]!.replacingOccurrences(of: " ", with: "") }
                if dicInfo["sexNm"] != nil {
                    let sexNm = dicInfo["sexNm"]!
                    if sexNm == "암" {
                        self.sexNm.text = sexNm + "소"
                    } else if sexNm == "거세" {
                        self.sexNm.text = sexNm + "우"
                    } else {
                        self.sexNm.text = sexNm
                    }
                }
                if dicInfo["birthYmd"] != nil {
                    let birthYmd = dicInfo["birthYmd"]!
                    self.monthsFromBirth.text = "출생: " + self.dateReadingForm(birthYmd)
                    self.animalAge.text = self.daysBetweenDate(startDate: birthYmd, endDate: butcheryYmd, unit: "month") + "개월령"
                }
                if dicInfo["butcheryWeight"] != nil { self.butcheryWeight.text = dicInfo["butcheryWeight"]! + "kg" }
                if dicInfo["qgradeNm"] != nil { self.qgradeNm.text = dicInfo["qgradeNm"]! + "등급" }
                if dicInfo["gradeNm"] != nil { self.qgradeNm.text = dicInfo["gradeNm"]! + "등급" }
                self.butcheryYmd.text = "도축: " + self.dateReadingForm(butcheryYmd)
                self.butcheryAge.text = "도축 후 " + self.daysBetweenDate(startDate: butcheryYmd, endDate: "today", unit: "") + "일 경과"
                if dicInfo["farmAddr"] != nil { self.daysFromButchery.text = "농장: " + dicInfo["farmAddr"]! }
                if dicInfo["butcheryPlaceNm"] != nil { self.butcheryPlaceNm.text = dicInfo["butcheryPlaceNm"]! }
            }
            if dicInfo["processPlaceNm"] != nil {
                self.processPlaceNm.text = "포장: " + dicInfo["processPlaceNm"]!
            } else {
                self.processPlaceNm.text = "포장 정보가 조회되지 않습니다. 업체에서 포장 정보를 등록하지 않은 것 같습니다."
            }
        }
    }

	// MARK: - Text recognition
    
    //data string to reading form. Input as "2022-03-24" or "20220324"
    func dateReadingForm(_ s: String) -> String {
        let sc = s.count
        if sc == 10 {
            return s[0..<4] + "년 " + String(Int(s[5..<7])!) + "월 " + String(Int(s[8..<10])!) + "일"
        } else if sc == 8 {
            return s[0..<4] + "년 " + String(Int(s[4..<6])!) + "월 " + String(Int(s[6..<8])!) + "일"
        } else {
            print("INPUT data wrong format. ERROR")
            return ""
        }
    }
    //Given date's DateComponent. Input as "2022-03-24" or "20220324"
    func givenDayDateComponent(startDate: String) -> DateComponents {
        var sdateArr: Array<String> = []
        let sc = startDate.count
        if sc == 10 {
            sdateArr = startDate.components(separatedBy: "-")
        } else if sc == 8 {
            sdateArr = [startDate[0..<4], startDate[4..<6], startDate[6..<8]]
        } else {
            print("FATAL ERROR: wrong date input. Why? \(startDate)")
        }
        // Specify date components
        var sdateComp = DateComponents()
        sdateComp.year = Int(sdateArr[0])!
        sdateComp.month = Int(sdateArr[1])!
        sdateComp.day = Int(sdateArr[2])!
        sdateComp.timeZone = TimeZone(abbreviation: "KST")
        sdateComp.hour = 0
        sdateComp.minute = 0
        return sdateComp
    }
    // today's DateComponent info
    func todayDateComponent() -> DateComponents {
        var edateArr: [String] = []
        let dateF = DateFormatter()    // 한국시각 오늘 날짜
        dateF.dateStyle = .short
        dateF.timeStyle = .medium
        dateF.timeZone = TimeZone(abbreviation: "KST")
        dateF.locale = Locale(identifier: "ja_JP")
        edateArr = dateF.string(from: Date()).components(separatedBy: " ")[0].components(separatedBy: "/")
        var edateComp = DateComponents() // end date 날짜 저장
        edateComp.year = Int(edateArr[0])!
        edateComp.month = Int(edateArr[1])!
        edateComp.day = Int(edateArr[2])!
        edateComp.timeZone = TimeZone(abbreviation: "KST")
        edateComp.hour = 0
        edateComp.minute = 0
        return edateComp
    }
    //Input dates as "2022-03-24" or "today", unit is "day" or "month"
    func daysBetweenDate(startDate: String, endDate: String, unit: String) -> String {
        let sdateComp = givenDayDateComponent(startDate: startDate)
        var edateComp = DateComponents()
        if endDate == "today" {
            edateComp = todayDateComponent()
        } else {
            edateComp = givenDayDateComponent(startDate: endDate)
        }
        // start date로부터 end date까지 경과일 계산
        if unit == "month" {
            return String(Calendar.current.dateComponents([.month], from: sdateComp, to: edateComp).month!+1)
        }
        return String(Calendar.current.dateComponents([.day], from: sdateComp, to: edateComp).day!)
    }
    
    func apiLoadCompletion(_ number: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let name = "urlSeoul"
        if let urlo = URL(string: urlSet[name]!["url"]!) {
            var request = URLRequest.init(url: urlo)
            request.httpMethod = "POST"
            let json: [String: Any] = [urlSet[name]!["name"]!: number, urlSet[name]!["check"]!: urlSet[name]!["checkv"]!]
            let jsonData = try? JSONSerialization.data(withJSONObject: json)
            request.httpBody = jsonData
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let headersa = ["x-api-key": urlSet[name]!["key"]!]
            for (k, value) in headersa {
                request.setValue(value, forHTTPHeaderField: k)
            }
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data else { return }
                completion(.success(data))
                // NEED TO ADD Failure case
            }.resume()
        }
    }
    func emptyNotify(_ number: String) {
        DispatchQueue.main.async {
            self.serviceNotices.text = "감지된 이력번호 \(number)가 잘못됐거나 전산에서 조회되지 않는 것 같습니다."
        }
    }
    func emptyNotifyGroup() {
        DispatchQueue.main.async {
            self.serviceNotices.text = "묶음구성내역 정보가 없거나 전산에서 조회되지 않는 것 같습니다."
        }
    }
    func emptyNotifyPreJsonSingle() {
        DispatchQueue.main.async {
            self.serviceNotices.text = "이력번호 정보가 없거나 전산에서 조회되지 않는 것 같습니다."
        }
    }
    func emptyNotifyPreJsonGroup() {
        DispatchQueue.main.async {
            self.serviceNotices.text = "묶음구성내역 정보가 없거나 전산에서 조회되지 않는 것 같습니다."
        }
    }
    struct statusJson: Codable {
        var statusCode: Int
    }
    struct bodyJson: Codable {
//        var statusCode: Int
//        var errorOccur: Bool
//        var apiUse: Bool
        var body: String
    }
    struct groupJson: Codable {
        var group: String
    }
    
    enum MyError: Error {
        case runtimeError(String)
    }
//    var stringArr: Array<String> = [] // substring of cattleNo Lot
//    var countArr: Int = 0 // stringArr.count
    func apiLoadAsync(_ number: String) {
        apiLoadCompletion(number) { (result) in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    do {// statusJson checking 200 respones. If not 200, then make error as following.
                        ////Swift.DecodingError.keyNotFound(CodingKeys(stringValue: "statusCode", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"statusCode\", intValue: nil) (\"statusCode\").", underlyingError: nil))
                        guard (try JSONDecoder().decode(statusJson.self, from: data).statusCode) == 200 else {
                            throw MyError.runtimeError("Guard: Wrong StatusCode Json:\(number) Not 200 Response.")
                        }
                        guard let preJson = try JSONDecoder().decode(bodyJson.self, from: data).body.data(using: .utf8) else {
                            self.emptyNotifyPreJsonSingle()
                            throw MyError.runtimeError("Guard: Wrong preJson:\(number) String Response.")
                        }
                        guard let jsonArray = try JSONSerialization.jsonObject(with: preJson, options : .allowFragments) as? Dictionary<String, String> else {
                            self.emptyNotify(number)
                            throw MyError.runtimeError("Guard: Wrong Json:\(number) String Response.")
                        }
                        self.detectedRecordArray[number] = jsonArray
                        self.clearIBOtext()
                        self.textLoadCattle(number)
                        guard "L02" == number[0..<3] else { throw MyError.runtimeError("If not: \(number) It is beef, but not L02 response.") }
                        guard let preJsonGroup = try JSONDecoder().decode(groupJson.self, from: data).group.data(using: .utf8) else {
                            self.emptyNotifyPreJsonGroup()
                            throw MyError.runtimeError("Guard: Wrong preJson Lot:\(number) String Response.")
                        }
                        guard let groupArray = try JSONSerialization.jsonObject(with: preJsonGroup, options : .allowFragments) as? Array<String> else {
                            self.emptyNotifyGroup()
                            throw MyError.runtimeError("Guard: Wrong group \(number) element response.")
                        }
                        if groupArray[0] == "error" { throw MyError.runtimeError("If not: \(number) It is Lot, but no group. \(groupArray)")
                        }
                        self.apiLoadAsyncArr(groupArray, lotNo: number)
                    } catch let error as NSError {
                        print(error)
                        return
                    }
                }
            case .failure(let error):
                print(error)
                return
            }
        }
    }
            
    //INPUT: cow's 12 digit number as String. eg. s: "002145745435"
    func checkingCowDigit (s: String) -> Bool {
        let dL = [3, 7, 9, 10, 5, 8, 4, 2] // checking number for each digit.
        var sum = 10
        for (i, d) in zip(s[3..<11], dL) {
            if i == "0" { continue }
            let n = i.wholeNumberValue!
            for _ in 1...n {
                sum += d
                sum = sum % 11
                if sum == 0 { sum += d }
            }
        }
        return String(11-sum).last! == s.last!
    }
    
    //Korean cow's nmuber as 002145745435
    func checkingKoreanCowSingle (s: String) -> Bool {
        if s.count != 12 { return false } // s must be 12 digits.
        for c in s {
            if c.isWholeNumber == false { return false } // s must be number.
        }
        if s[0..<3] != "002" { return false } // s must start with 002
        if checkingCowDigit(s: s) == false { return false } // Check the last digit
        return true
    }

    //
    func isLeapYear(_ year: Int) -> Bool {
        return ((year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0))}
    
    // check past date. Input as "210811" means 2021 year August 11th day
    func checkingPastDate(s: String) -> Bool {
        let sy = "20"+s[0..<2]
        let sm = s[2..<4]
        let sd = s[4..<6]
        if Int(sy)! > todayDateComponent().year! { return false }
        if Int(sm)! > 12 { return false }
        if Int(sd)! > 31 { return false }
        if ["04","06","09","11"].contains(sm) == true && Int(sd)! > 30 { return false }
        if sm == "02" && Int(sd)! > 29 { return false }
        if sm == "02" && isLeapYear(Int(sy)!) == false && Int(sd)! > 28 { return false }
        if Int(daysBetweenDate(startDate: sy+"-"+sm+"-"+sd, endDate: "today", unit: "day"))! < 0 { return false }
        return true
    }

    //Korean animal's old group nmuber as LOT111117001
    func checkingKoreanAnimalGroupLOT12 (s: String) -> Bool {
        if s.count != 12 { return false } // s must be 12 digits.
        if s[0..<3] != "LOT" { return false } // s must start with LOT
        for c in s[3..<12] {
            if c.isWholeNumber == false { return false } // s[3...] must be number.
        }
        if checkingPastDate(s: s[3..<9]) == false { return false } // Check the packing date
        return true
    }
    
    //Korean animal's group nmuber as L02207253051001
    func checkingKoreanAnimalGroupL15 (s: String) -> Bool {
        if s.count != 15 { return false } // s must be 12 digits.
        if s[0..<1] != "L" { return false } // s must start with L
        for c in s[1..<15] {
            if c.isWholeNumber == false { return false } // s[1...] must be number.
        }
        if ["0","1","2","5"].contains(s[1..<2]) == false { return false } // For group packing, 0 is beef, 1 is pork, 2 is chicken, 5 is duck
        if checkingPastDate(s: s[2..<8]) == false { return false } // Check the packing date
        return true
    }
    
    //INPUT: 10 digit number as String. eg. s: "5068202384"
    func checkingBusinessNumber (s: String) -> Bool {
        let dL = [1, 3, 7, 1, 3, 7, 1, 3, 5] // checking number for each digit.
        var sum = 0
        for (i, d) in zip(s[0..<9], dL) {
            let n = i.wholeNumberValue!
            sum += n * d
        }
        sum += Int(s[8..<9])! * dL[8] / 10
        sum = sum % 10
        return String(10-sum).last! == s.last!
    }

    //Imported animal's group nmuber as A41535850069100022073122
    func checkingImportedAnimalGroupA24 (s: String) -> Bool {
        if s.count != 24 { return false } // s must be 12 digits.
        if s[0..<1] != "A" { return false } // s must start with L
        for c in s[1..<24] {
            if c.isWholeNumber == false { return false } // s[1...] must be number.
        }
        if ["41","42"].contains(s[1..<3]) == false { return false } // For group packing, 41 is beef, 42 is pork
        if checkingBusinessNumber(s: s[3..<13]) == false { return false } // Check the business number.
        if checkingPastDate(s: s[16..<22]) == false { return false } // Check the packing date
        return true
    }
    //Korean pig's nmuber as 160107700484
    func checkingKoreanPigSingle (s: String) -> Bool {
        if s.count != 12 { return false } // s must be 12 digits.
        for c in s {
            if c.isWholeNumber == false { return false } // s must be number.
        }
        if s == "111111111111" { return false } // s is not barcode
        if s[0..<1] != "1" { return false } // s must start with 1
        return true
    }
    //Imported pig's nmuber as 912004100594
    func checkingImportedPigSingle (s: String) -> Bool {
        if s.count != 12 { return false } // s must be 12 digits.
        for c in s {
            if c.isWholeNumber == false { return false } // s must be number.
        }
        if s[0..<1] != "9" { return false } // s must start with 9
        return true
    }
    //Imported cow's nmuber as 803058101125
    func checkingImportedCowSingle (s: String) -> Bool {
        if s.count != 12 { return false } // s must be 12 digits.
        for c in s {
            if c.isWholeNumber == false { return false } // s must be number.
        }
        if s[0..<1] != "8" { return false } // s must start with 8
        return true
    }
    //Korean chicken's nmuber as 220010901401
    func checkingKoreanChickenSingle (s: String) -> Bool {
        if s.count != 12 { return false } // s must be 12 digits.
        for c in s {
            if c.isWholeNumber == false { return false } // s must be number.
        }
        if s[0..<1] != "2" { return false } // s must start with 2
        return true
    }
    //Korean egg's nmuber as 301100070020
    func checkingKoreanEggSingle (s: String) -> Bool {
        if s.count != 12 { return false } // s must be 12 digits.
        for c in s {
            if c.isWholeNumber == false { return false } // s must be number.
        }
        if s[0..<1] != "3" { return false } // s must start with 3
        return true
    }
    //Korean duck's nmuber as 520011001801
    func checkingKoreanDuckSingle (s: String) -> Bool {
        if s.count != 12 { return false } // s must be 12 digits.
        for c in s {
            if c.isWholeNumber == false { return false } // s must be number.
        }
        if s[0..<1] != "5" { return false } // s must start with 5
        return true
    }
    //Check Initial condition for given 12 digit string
    func checkingValidateInput (s: String) -> Bool {
        let sini = s[0..<1]
        if sini == "0" && checkingKoreanCowSingle(s: s) == true { return true }
        //
        if s[0..<3] == "LOT" && checkingKoreanAnimalGroupLOT12 (s: s) == true { return true }
        if sini == "L" && checkingKoreanAnimalGroupL15 (s: s) == true { return true }
        if sini == "A" && checkingImportedAnimalGroupA24 (s: s) == true { return true }
        if sini == "1" && checkingKoreanPigSingle (s: s) == true { return true }
        if sini == "9" && checkingImportedPigSingle (s: s) == true { return true }
        if sini == "8" && checkingImportedCowSingle (s: s) == true { return true }
        if sini == "2" && checkingKoreanChickenSingle (s: s) == true { return true }
        if sini == "3" && checkingKoreanEggSingle (s: s) == true { return true }
        if sini == "5" && checkingKoreanDuckSingle (s: s) == true { return true }
        return false
    }
    
	// Vision recognition handler.
	func recognizeTextHandler(request: VNRequest, error: Error?) {
		var numbers = [String]()
		var redBoxes = [CGRect]() // Shows all recognized text lines
		var greenBoxes = [CGRect]() // Shows words that might be serials
		
		guard let results = request.results as? [VNRecognizedTextObservation] else {
			return
		}
		let maximumCandidates = 1
        //
        for (n, observation) in results.enumerated() {
            let ts = observation.topCandidates(1).first!.string
            var ts3 = ""
            if n < results.count - 3 {
                ts3 = observation.topCandidates(1).first!.string + results[n+1].topCandidates(1).first!.string + results[n+2].topCandidates(1).first!.string + results[n+3].topCandidates(1).first!.string
            }
            ts3 = ts3.replacingOccurrences(of: " ", with: "")[0..<12]
            var ts3ch = true
            if ts3 != "" {
                for c in ts3 {
                    if c.isWholeNumber == false {
                        ts3ch = false
                        break
                    }
                }
            } else { ts3ch = false }
            //
            // Cow case
            if ts[0..<3] != "002" && ts[0..<3] != "L02" { continue }
            if ts3[0..<3] != "002" && ts3[0..<3] != "L02" { continue }
            //
            var detectedRecord = ""
            if self.detectedRecords != [] { detectedRecord = self.detectedRecords[self.detectedRecords.count-1] }
//            if ts3ch && ts != ts3 && ts3 != detectedRecord { print("ts3:\(ts3)") }
            if checkingValidateInput(s: ts) {
//                print("ts\(ts):-self:\(self.detectedRecords)")
                // Several search
                //if detectedRecordArray.keys.contains(ts) { continue }
                if detectedRecord == ts { continue }
                self.detectedRecords.append(ts)
//                print("\(Date()):\(ts)")
                self.clearIBOtext()
                self.waitingNotify()
                if detectedRecordArray.keys.contains(ts) == false {
                    print("\(Date()):\(ts) API LOADING....TS")
//                    saveAnimalData(webString: apiLoadUrl(number: ts), cowNumber: ts)
                    apiLoadAsync(ts)
                    print("\(Date()):\(ts) API DONE.TS")
                } else {
                    print("\(Date()):\(ts) TS NO CALL API")
                    self.clearIBOtext()
                    textLoadCattle(ts)
                    textLoadCattleSubs(ts)
                }
//                print(String(describing: detectedRecordArray[ts]!))
            } else if checkingValidateInput(s: ts3) {
//                print("ts3\(ts3):-self:\(self.detectedRecords)")
                //if detectedRecordArray.keys.contains(ts3) { continue }
                if detectedRecord == ts3 { continue }
                self.detectedRecords.append(ts3)
//                print("ts3:\(Date()):\(ts3)")
                self.clearIBOtext()
                self.waitingNotify()
                if detectedRecordArray.keys.contains(ts3) == false {
                    print("\(Date()):\(ts3) API LOADING....TS3")
//                    saveAnimalData(webString: apiLoadUrl(number: ts3), cowNumber: ts3)
                    apiLoadAsync(ts3)
                    print("\(Date()):\(ts3) API DONE.TS3")
                } else {
                    print("\(Date()):\(ts3) TS3 NO CALL API")
                    self.clearIBOtext()
                    textLoadCattle(ts3)
                    textLoadCattleSubs(ts3)
                }
//                print(String(describing: detectedRecordArray[ts3]!))
            }
        }
        return
        //
		for visionResult in results {
			guard let candidate = visionResult.topCandidates(maximumCandidates).first else { continue }

			// Draw red boxes around any detected text, and green boxes around
			// any detected phone numbers. The phone number may be a substring
			// of the visionResult. If a substring, draw a green box around the
			// number and a red box around the full string. If the number covers
			// the full result only draw the green box.
			var numberIsSubstring = true

			if let result = candidate.string.extractPhoneNumber() {
				let (range, number) = result
				// Number may not cover full visionResult. Extract bounding box
				// of substring.
				if let box = try? candidate.boundingBox(for: range)?.boundingBox {
					numbers.append(number)
					greenBoxes.append(box)
					numberIsSubstring = !(range.lowerBound == candidate.string.startIndex && range.upperBound == candidate.string.endIndex)
				}
			}
			if numberIsSubstring {
				redBoxes.append(visionResult.boundingBox)
			}
		}

		// Log any found numbers.
		numberTracker.logFrame(strings: numbers)
		show(boxGroups: [(color: UIColor.red.cgColor, boxes: redBoxes), (color: UIColor.green.cgColor, boxes: greenBoxes)])

		// Check if we have any temporally stable numbers.
		if let sureNumber = numberTracker.getStableString() {
			showString(string: sureNumber)
			numberTracker.reset(string: sureNumber)
		}
	}
	
	override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
			// Configure for running in real-time.
			request.recognitionLevel = .fast
			// Language correction won't help recognizing phone numbers. It also
			// makes recognition slower.
			request.usesLanguageCorrection = false
			// Only run on the region of interest for maximum speed.
			request.regionOfInterest = regionOfInterest
			
			let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: textOrientation, options: [:])
			do {
				try requestHandler.perform([request])
			} catch {
				print(error)
			}
		}
	}
	
	// MARK: - Bounding box drawing
	
	// Draw a box on screen. Must be called from main queue.
	var boxLayer = [CAShapeLayer]()
	func draw(rect: CGRect, color: CGColor) {
		let layer = CAShapeLayer()
        layer.opacity = 0.5
		layer.borderColor = color
		layer.borderWidth = 1
		layer.frame = rect
		boxLayer.append(layer)
		previewView.videoPreviewLayer.insertSublayer(layer, at: 1)
	}
	
	// Remove all drawn boxes. Must be called on main queue.
	func removeBoxes() {
		for layer in boxLayer {
			layer.removeFromSuperlayer()
		}
		boxLayer.removeAll()
	}
	
	typealias ColoredBoxGroup = (color: CGColor, boxes: [CGRect])
	
	// Draws groups of colored boxes.
	func show(boxGroups: [ColoredBoxGroup]) {
		DispatchQueue.main.async {
			let layer = self.previewView.videoPreviewLayer
			self.removeBoxes()
			for boxGroup in boxGroups {
				let color = boxGroup.color
				for box in boxGroup.boxes {
					let rect = layer.layerRectConverted(fromMetadataOutputRect: box.applying(self.visionToAVFTransform))
					self.draw(rect: rect, color: color)
				}
			}
		}
	}
}
