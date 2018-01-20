//
//  ViewController.swift
//  LinSpell
//
//  Created by Shyngys Kassymov on 19.01.2018.
//  Copyright © 2018 Shyngys Kassymov. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var resultLabel: UILabel?

    var backgroundQueue = OperationQueue()

    var resultsText = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        LinSpell.verbose = .top
        LinSpell.editDistanceMax = 2

        print("Creating dictionary ...")

        let start = DispatchTime.now()

        // Load a frequency dictionary
        // wordfrequency_en.txt  ensures high correction quality by combining two data sources:
        // Google Books Ngram data  provides representative word frequencies (but contains many entries with spelling errors)
        // SCOWL — Spell Checker Oriented Word Lists which ensures genuine English vocabulary (but contained no word frequencies)
        // let path = Bundle.main.path(forResource: "frequency_dictionary_en_30_000", ofType: "txt") // for benchmark only (contains also non-genuine English words)
        // let path = Bundle.main.path(forResource: "frequency_dictionary_en_500_000", ofType: "txt") // for benchmark only (contains also non-genuine English words)
        let path = Bundle.main.path(forResource: "frequency_dictionary_en_82_765", ofType: "txt") // for spelling correction (genuine English words)
        if path != nil {
            if !LinSpell.loadDictionary(corpus: path!, termIndex: 0, countIndex: 1) {
                print("File not found: " + path!)
            }
        }

        // Alternatively Create the dictionary from a text corpus (e.g. http://norvig.com/big.txt )
        // Make sure the corpus does not contain spelling errors, invalid terms and the word frequency is representative to increase the precision of the spelling correction.
        // The dictionary may contain vocabulary from different languages.
        // If you use mixed vocabulary use the language parameter in lookupLinear() and createDictionary() accordingly.
        // let path = Bundle.main.path(forResource: "big", ofType: "txt")
        // if path != nil {
        //     if !LinSpell.createDictionary(corpus: path!, language: "en") {
        //         print("File not found: " + path!)
        //     }
        // }

        let end = DispatchTime.now()

        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000

        print("Dictionary: \(LinSpell.dictionaryLinear.count) words, edit distance = \(LinSpell.editDistanceMax) in \(timeInterval) ms \(currentMemoryUsageInMB()) MB")
    }

    private func currentMemoryUsageInMB() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size / 1024 / 1024
        }
        return 0
    }

    // MARK: - Actions

    @IBAction func correct(_ textField: UITextField) {
        guard let text = textField.text else {
            return
        }

        backgroundQueue.cancelAllOperations()

        backgroundQueue.addOperation { [weak self] in
//            print("***** LOOKUP START *****")

            let start = DispatchTime.now()
            let results = LinSpell.lookupLinear(input: text)
            let end = DispatchTime.now()

//            print("***** LOOKUP END *****")

            let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
            let timeInterval = Double(nanoTime) / 1_000_000

            let limit = min(LinSpell.topResultsLimit, results.count)
            self?.resultsText = ""
            self?.resultsText = Array(results.prefix(upTo: limit)).map{ $0.term }.joined(separator: "\n")
            if results.count == 0 {
                self?.resultsText = "No results :("
            }
            self?.resultsText += "\n\nLookup time: \(timeInterval) ms"

            OperationQueue.main.addOperation {
                self?.resultLabel?.text = self?.resultsText
            }
        }
    }

}

