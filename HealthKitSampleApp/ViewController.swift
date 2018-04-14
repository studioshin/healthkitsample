//
//  ViewController.swift
//  HealthKitSampleApp
//
//

import UIKit
import HealthKit

class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		
		// 読み込み情報タイプ
		let readTypes: Set<HKObjectType> = [
			HKQuantityType.quantityType(forIdentifier: .height)!,						//身長
			HKQuantityType.quantityType(forIdentifier: .bodyMass)!,						//体重
			HKQuantityType.quantityType(forIdentifier: .stepCount)!,					//歩数
			
			HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,			//生年月日
			HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,		//性別
			HKCharacteristicType.characteristicType(forIdentifier: .fitzpatrickSkinType)!,	//肌タイプ
			HKCharacteristicType.characteristicType(forIdentifier: .bloodType)!,			//血液型
			HKCharacteristicType.characteristicType(forIdentifier: .wheelchairUse)!,		//車椅子使用
		]
		// 書き込み情報タイプ
		let shareTypes: Set<HKSampleType> = [
			HKSampleType.quantityType(forIdentifier: .bodyMass)!,					//体重
		]
		
		//アクセス許可
		let healthStore: HKHealthStore = HKHealthStore()
		healthStore.requestAuthorization(toShare: shareTypes, read: readTypes, completion: { (success, error) in
			if let er = error {
				print("\(er.localizedDescription)")
			} else {
				print("成功: \(success)")
				
				
				//全歩数
				self.stepCountAll(handler: { (steps) in
					self.stepCountLabel.text = "\(steps)"
				})
				
//				//今日の歩数
//				self.stepCount(at: Date(), handler: { (step) in
//					self.stepCountLabel.text = "\(step)"
//				})
				
//				//今日の歩数（１時間毎）
//				self.stepCountTodayEveryHour(at: Date(), handler: { (data) in
//					for d in data {
//						print("\(d)")
//					}
//				})
			}
			
			
		})
		
	}
	
	//歩数取得（全部）
	func stepCountAll(handler: @escaping ((_ stepCount: Int) -> Void) ) {
		
		let type: HKQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
		let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 0, sortDescriptors: nil) { (query, samples, error) in
			if let er = error {
				print("\(er.localizedDescription)")
			} else {
				if let sms = samples, sms.count > 0 {
					var steps: Double = 0
					for sample in sms {
						let quantitySample = sample as! HKQuantitySample
						let unit: HKUnit = HKUnit.count()
						let step = quantitySample.quantity.doubleValue(for: unit)
						steps += step
					}
					DispatchQueue.main.async {
						handler(Int(steps))
					}
				}
			}
		}
		let healthStore: HKHealthStore = HKHealthStore()
		healthStore.execute(query)
	}
	
	//歩数(指定日)
	func stepCount(at: Date, handler: @escaping ((_ stepCount: Int) -> Void) ) {
		
		//タイプとして歩数
		let type: HKQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
		//指定日の0時を指定
		let calender = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)!
		let unit: NSCalendar.Unit = [.year, .month, .day]
		let comps: DateComponents = calender.components(unit, from: at)
		let dateString = "\(comps.year!)-\(comps.month!)-\(comps.day!) 00:00:00"
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: NSLocale.Key.languageCode.rawValue)
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		let date = formatter.date(from: dateString)!
		//１日を指定
		var components = DateComponents()
		components.day = 1
		//統計コレクションクエリを作成
		let query = HKStatisticsCollectionQuery(quantityType: type, 
												quantitySamplePredicate: nil, 
												options: [.cumulativeSum], 
												anchorDate: date, intervalComponents: components)
		query.initialResultsHandler = {(query, result, error) in
			if let er = error {
				print("\(er.localizedDescription)")
			} else {
				if let res = result {
					res.enumerateStatistics(from: date, to: Date(), with: { (statistics, stop) in
						if let sumQuantity = statistics.sumQuantity() {
							let unit: HKUnit = HKUnit.count()
							let step = sumQuantity.doubleValue(for: unit)
							DispatchQueue.main.async {
								handler(Int(step))
							}
						}
					})
				}
			}
		}
		let healthStore: HKHealthStore = HKHealthStore()
		healthStore.execute(query)
	}
	
	//歩数（１時間毎）
	func stepCountTodayEveryHour(at: Date, handler: @escaping ((_ stepData: [(step: Double, startDate: Date, endDate: Date)]) -> Void)) {
		
		//タイプ
		let type: HKQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
		//指定日の0時を指定
		let calender = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)!
		let unit: NSCalendar.Unit = [.year, .month, .day]
		let comps: DateComponents = calender.components(unit, from: at)
		let dateString = "\(comps.year!)-\(comps.month!)-\(comps.day!) 00:00:00"
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: NSLocale.Key.languageCode.rawValue)
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		let date = formatter.date(from: dateString)!
		var components = DateComponents()
		//１時間を指定
		components.hour = 1
		let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: nil, options: [.cumulativeSum], anchorDate: date, intervalComponents: components)
		query.initialResultsHandler = {(query, result, error) in
			if let er = error {
				print("\(er.localizedDescription)")
			} else {
				if let res = result {
					var ret: [(step: Double, startDate: Date, endDate: Date)] = []
					res.enumerateStatistics(from: date, to: Date(), with: { (statistics, stop) in
						if let sumQuantity = statistics.sumQuantity() {
							let unit: HKUnit = HKUnit.count()
							let step = sumQuantity.doubleValue(for: unit)
							let data = (step:step, startDate:statistics.startDate, endDate:statistics.endDate)
							ret.append(data)
							DispatchQueue.main.async {
								handler(ret)
							}
						}
					})
				}
			}
		}
		let healthStore: HKHealthStore = HKHealthStore()
		healthStore.execute(query)
	}
	
	
	@IBOutlet weak var stepCountLabel: UILabel!
	
	@IBOutlet weak var weightTextField: UITextField!
	@IBAction func weightSaveButtonAction(_ sender: Any) {
		
		self.weightTextField.resignFirstResponder()
		
		//許可確認
		let healthStore: HKHealthStore = HKHealthStore()
		//タイプ
		let type: HKQuantityType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
		let authorizedStatus = healthStore.authorizationStatus(for: type)		
		if authorizedStatus == .sharingAuthorized {
			// 体重を保存する
			if let text = self.weightTextField.text, let weight = Double(text) {
				//単位(グラム)
				let unit: HKUnit = HKUnit.gram()
				//体重の値
				let weight: HKQuantity = HKQuantity(unit: unit, doubleValue: weight * 1000)
				
				//保存データ作成
				let sample: HKQuantitySample = HKQuantitySample(type: type, quantity: weight, start: Date(), end: Date())
				
				//保存
				HKHealthStore().save([sample]) { (success, error) in
					if let er = error {
						print("\(er.localizedDescription)")
					} else {
						print("体重保存成功")
						
					}
				}
			}
		}
	}
	
	
}

