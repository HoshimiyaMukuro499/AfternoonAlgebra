extends Control

signal tutorial_finished

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var start_button: Button = $StartButton

func _ready():
	start_button.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed():
	tutorial_finished.emit()
	queue_free()
