<?php

class ActiveColorPalette extends CWidget
{
  /**
   * @var CActiveRecord model
   */
  public $model;
  /**
   * @var name of the CActiveRecord model attribute
   */
  public $attribute;
  /**
   * @var whether the textfield with the hex value is shown or not (next to the color picker)
   */
  public $hidden = false;
  /**
   * @var array miniColors jQuery plugin options
   */
  public $options = array();
  /**
   * @var array input element attributes
   */
  public $htmlOptions = array();

  /**
	 * Initializes the widget.
	 * This method will publish jQuery and miniColors plugin assets if necessary.
   * @return void
	 */
  public function init()
  {
    $activeId = CHtml::activeId($this->model, $this->attribute);

    $dir = dirname(__FILE__).DIRECTORY_SEPARATOR.'source';
    $baseUrl = Yii::app()->getAssetManager()->publish($dir);

    $cs = Yii::app()->getClientScript();
    $cs->registerCoreScript('jquery');
    $cs->registerScriptFile($baseUrl.'/jquery.colorPicker.min.js');
    $cs->registerCssFile($baseUrl.'/colorPicker.css');

    $options = CJavaScript::encode($this->options);

    $cs->registerScript('miniColors-'.$activeId, '$("#'.$activeId.'").colorPicker('.$options.');');
  }

  /**
	 * Renders the widget.
   * @return void
	 */
  public function run()
  {
    if ($this->hidden)
      echo CHtml::activeHiddenField($this->model, $this->attribute, $this->htmlOptions);
    else
      echo CHtml::activeTextField($this->model, $this->attribute, $this->htmlOptions);
  }
}
