import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var colorButton: UIButton!

    var textColor: UIColor = (red: 0.56, green: 0.56, blue: 0.56, alpha: 1.00)

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure Text Field
        textField.placeholder = "YouTube"

        // Configure Color Button
        colorButton.setTitleColor(textColor, for: .normal)
    }

    @IBAction func onColorButtonTap(_ sender: Any) {
        let colorPicker = UIColorPickerViewController()
        colorPicker.delegate = self
        present(colorPicker, animated: true, completion: nil)
    }
}

extension ViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension ViewController: UIColorPickerViewControllerDelegate {

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        textColor = viewController.selectedColor
        colorButton.setTitleColor(textColor, for: .normal)
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        dismiss
