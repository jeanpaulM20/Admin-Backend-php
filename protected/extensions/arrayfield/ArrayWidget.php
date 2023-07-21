<?php

class ArrayWidget extends CWidget
{

	public $model;
	public $name;
	public $values = array();
	public $urlPart;
	public $connectionField;
	public $connectionId;
	public $sorting = true;

	public function init()
	{
		parent::init();
		if ($this->sorting) {
			$cs			 = Yii::app()->getClientScript();
			$cs->registerCoreScript('jquery.ui');
		}
	}

	public function run()
	{
		echo '<div class="array_field_wrapper">';
			echo '<ul id="' . $this->name . '_container">';
			foreach ($this->values as $one) {
				echo '<li id="item_' . $one->getPrimaryKey() . '"><a class="array_edit" href="' . Yii::app()->createUrl($this->urlPart . '/update/id/' . $one->getPrimaryKey()) . '">e</a> <a class="array_delete" href="' . Yii::app()->createUrl($this->urlPart . '/delete/id/' . $one->getPrimaryKey()) . '">x</a> ' . $one->getModelDisplay() . '</li>';
			}
			echo '</ul>';
			echo '<a class="array_add" href="' . Yii::app()->createUrl($this->urlPart . '/create', array($this->connectionField => $this->connectionId)) . '" id="' . $this->name . '_add">+</a><br/>';
		echo '</div>';
		if ($this->sorting) {
			$js = '
				function resertSorting() {
					$("#' . $this->name . '_container").sortable({
						forcePlaceholderSize: true,
						forceHelperSize: true,
						cursor: "move",
						items: "li",
						update : function () {
							serial = $("#' . $this->name . '_container").sortable("serialize", {key: "items[]", attribute: "id"});
							$.ajax({
								"url": "' . Yii::app()->createUrl('//' . $this->urlPart . '/sort') . '",
								"type": "post",
								"data": serial
							});
						},
					});
					$("#' . $this->name . '_container").disableSelection();	
				}
				resertSorting();
			';
			Yii::app()->getClientScript()->registerScript(__CLASS__.'#'.$this->name, $js);
		}
	}

}