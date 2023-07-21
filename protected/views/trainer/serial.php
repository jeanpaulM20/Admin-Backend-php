<?php
$this->pageTitle='Trainer avalibility serial input';
$this->breadcrumbs=array(
	'Trainers'=>array('admin'),
	$trainer->getModelDisplay(),
	'Serial avalibility',
);
?>

<h1>Serial avalibility</h1>

<p>Please fill out the following form with your login credentials:</p>

<div class="form">
<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'login-form',
	'enableClientValidation'=>true,
	'clientOptions'=>array(
		'validateOnSubmit'=>true,
	),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<fieldset>
		<legend>Avaliability data</legend>
		<div class="row">
			<?php echo $form->labelEx($model, 'location_id'); ?>
			<?php echo CHtml::activeDropDownList($model, 'location_id', Location::getDropdownList(), array('style' => 'width:260px;')) ?>
			<?php echo $form->error($model, 'location_id'); ?>
		</div>

		<div class="row">
			<?php echo $form->labelEx($model, 'training_type_id'); ?>
			<?php echo CHtml::activeDropDownList($model, 'training_type_id', TrainingType::getDropdownList(), array('style' => 'width:260px;')) ?>
			<?php echo $form->error($model, 'training_type_id'); ?>
		</div>

		<div class="row">
			<?php echo $form->labelEx($model, 'from'); ?>
			<?php
			$this->widget('application.extensions.timepicker.EJuiDateTimePicker', array(
				'model'			 => $model,
				'attribute'		 => 'from',
				'timePickerOnly' => true,
				'options'		 => array(
					'timeFormat' => 'hh:mm',
					'stepMinute'		 => 15,
				),
			));
			?>
			<?php echo $form->error($model, 'from'); ?>
		</div>

		<div class="row toField">
			<?php echo $form->labelEx($model, 'to'); ?>
			<?php
			$this->widget('application.extensions.timepicker.EJuiDateTimePicker', array(
				'model'			 => $model,
				'attribute'		 => 'to',
				'timePickerOnly' => true,
				'options'		 => array(
					'timeFormat' => 'hh:mm',
					'stepMinute'		 => 15,
				),
			));
			?>
			<?php echo $form->error($model, 'to'); ?>
		</div>
	</fieldset>
	<fieldset>
		<legend>Reccurence pattern</legend>
		<div class="left" style="padding: 10px; border-right: 1px solid black;">
			<?php echo CHtml::activeRadioButtonList($model, 'reccurence', $model->getReccurenceList()) ?>
			<?php echo $form->error($model,'reccurence'); ?>
		</div>
		<div class="left reccurence weekly" style="padding: 10px;">
			Reccur every <?php echo $form->textField($model,'everyWeek'); ?> week(s) on: <br/>
			<div class="clear"></div>
			<div class="left" style="padding: 5px;">
				<?php echo $form->checkBox($model,'rMonday'); ?>
				<?php echo $form->label($model,'rMonday'); ?>
			</div>	
			<div class="left" style="padding: 5px;">
				<?php echo $form->checkBox($model,'rTuesday'); ?>
				<?php echo $form->label($model,'rTuesday'); ?>
			</div>	
			<div class="left" style="padding: 5px;">
				<?php echo $form->checkBox($model,'rWednesday'); ?>
				<?php echo $form->label($model,'rWednesday'); ?>
			</div>	
			<div class="left" style="padding: 5px;">
				<?php echo $form->checkBox($model,'rThursday'); ?>
				<?php echo $form->label($model,'rThursday'); ?>
			</div>	
			<div class="left" style="padding: 5px;">
				<?php echo $form->checkBox($model,'rFriday'); ?>
				<?php echo $form->label($model,'rFriday'); ?>
			</div>	
			<div class="left" style="padding: 5px;">
				<?php echo $form->checkBox($model,'rSatturday'); ?>
				<?php echo $form->label($model,'rSatturday'); ?>
			</div>	
			<div class="left" style="padding: 5px;">
				<?php echo $form->checkBox($model,'rSunday'); ?>
				<?php echo $form->label($model,'rSunday'); ?>
			</div>	
			<?php echo $form->error($model,'everyWeek'); ?>
		</div>
		<div class="left reccurence monthly" style="padding: 10px; display: none">
			Day <?php echo $form->textField($model,'rDay'); ?> of every <?php echo $form->textField($model,'everyMonth'); ?> month(s)
			<?php echo $form->error($model,'rDay'); ?>
			<?php echo $form->error($model,'everyMonth'); ?>
		</div>
	</fieldset>
	<fieldset>
		<legend>Range of reccurence</legend>
		<div class="left" style="padding: 10px;">
			Start: <?php
			$this->widget('zii.widgets.jui.CJuiDatePicker', array(
				'attribute'	 => 'rStart',
				'model'		 => $model,
				'options'	 => array(
					'showAnim'	 => 'fold',
					'dateFormat' => 'dd-mm-yy'
				),
			));
			?><br/>
			<?php echo $form->error($model, 'rStart'); ?>
		</div>
		<div class="left" style="padding: 10px;">
			<?php echo CHtml::activeRadioButton($model, 'rRange', array('value' => 'after', 'uncheckValue' => null)) ?> End after:  <?php echo $form->textField($model,'rEndAfter'); ?> occurence(s)<br/>
			<?php echo $form->error($model, 'rEndAfter'); ?>
			<?php echo CHtml::activeRadioButton($model, 'rRange', array('value' => 'end', 'uncheckValue' => null)) ?> End by:  
			<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
				'attribute'	 => 'rEnd',
				'model'		 => $model,
				'options'	 => array(
					'showAnim'	 => 'fold',
					'dateFormat' => 'dd-mm-yy'
				),
			)); ?>
			<?php echo $form->error($model, 'rEnd'); ?>
		</div>
	</fieldset>
	<div class="row buttons">
		<?php echo CHtml::submitButton('Save'); ?>
	</div>

<?php $this->endWidget(); ?>
</div><!-- form -->
<script type="text/javascript">
	$("input[name='SerialAvalibilityForm[reccurence]']").change(function() {
		$('.reccurence').hide();
		$('.' + $("input[name='SerialAvalibilityForm[reccurence]']:checked").val()).show();
	});
	$('.reccurence').hide();
	$('.' + $("input[name='SerialAvalibilityForm[reccurence]']:checked").val()).show();
</script>
