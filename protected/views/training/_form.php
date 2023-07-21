<div class="form">

<?php $form=$this->beginWidget('CActiveForm', array(
	'id'=>'training-form',
	'enableAjaxValidation'=>false,
	'action' => $model->isNewRecord ? $this->createUrl('training/create') : $this->createUrl('training/update', array('id' => $model->id)),
	'htmlOptions' => array('enctype' => 'multipart/form-data'),
)); ?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>

	<?php echo $form->errorSummary($model); ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'date'); ?>
	<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
		'attribute'=>'date',
		'model' => $model,
		'options'=>array(
			'showAnim'=>'fold',
			'dateFormat' => 'yy-mm-dd'		),
	)); ?>
	<?php echo $form->error($model,'date'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'starttime'); ?>
	<?php $this->widget('application.extensions.timepicker.EJuiDateTimePicker',array(
		'model'=>$model,
		'attribute'=>'starttime',
		'timePickerOnly' => true,
		'options'=>array(
			'timeFormat' => 'hh:mm',
		),
	)); ?>
	<?php echo $form->error($model,'starttime'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'type'); ?>
	<?php echo $form->dropDownList($model,'type', TrainingType::getDropdownList()); ?>
	<?php echo $form->error($model,'type'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'text'); ?>
	<?php echo $form->textArea($model,'text',array('size'=>60)); ?>
	<?php echo $form->error($model,'text'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'status'); ?>
	<?php echo $form->dropDownList($model,'status', $model->getStatusValues()); ?>
	<?php echo $form->error($model,'status'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'cancelled_at'); ?>
	<?php $this->widget('zii.widgets.jui.CJuiDatePicker', array(
		'attribute'=>'cancelled_at',
		'model' => $model,
		'options'=>array(
			'showAnim'=>'fold',
			'dateFormat' => 'yy-mm-dd'		),
	)); ?>
	<?php echo $form->error($model,'cancelled_at'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'cancelled_by_client_rel'); ?>
	<?php echo $form->dropDownList($model,'cancelled_by_client_rel', Client::getDropdownList(true)); ?>
	<?php echo $form->error($model,'cancelled_by_client_rel'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'cancelled_by_trainer_rel'); ?>
	<?php echo $form->dropDownList($model,'cancelled_by_trainer_rel', Trainer::getDropdownList(true)); ?>
	<?php echo $form->error($model,'cancelled_by_trainer_rel'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'client_id'); ?>
	<?php echo $form->dropDownList($model,'client_id', Client::getDropdownList(), array('id' => 'client_select')); ?>
	<?php echo $form->error($model,'client_id'); ?></div>
	<?php /*
	<div class="row">
	<?php echo $form->labelEx($model,'goals'); ?>
	<?php echo CHtml::activeDropDownList($model, 'goals', Goal::getDropdownListByClientId($model->client_id), array('multiple' => true, 'class' => 'chzn-select', 'style' => 'width:380px;', 'id' => 'goal-select')) ?>
	<?php echo $form->error($model,'goals'); ?>
	</div> */ ?>
	
	<div class="row">
	<?php echo $form->labelEx($model,'location_id'); ?>
	<?php echo $form->dropDownList($model,'location_id', Location::getDropdownList()); ?>
	<?php echo $form->error($model,'location_id'); ?></div>
	<div class="row">
	<?php echo $form->labelEx($model,'trainer_id'); ?>
	<?php echo $form->dropDownList($model,'trainer_id', Trainer::getDropdownList(true)); ?>
	<?php echo $form->error($model,'trainer_id'); ?></div>
		
	<div class="row">
<?php echo $form->labelEx($model,'exercisesets'); ?>
<?php echo CHtml::activeDropDownList($model, 'exercisesets', Exerciseset::getDropdownList(), array('multiple' => true, 'class' => 'chzn-select', 'style' => 'width:380px;')) ?>
<?php echo $form->error($model,'exercisesets'); ?>
</div>

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save'); ?>
		<?php
			echo CHtml::htmlButton('Cancel', array(
				'onclick' => 'window.location="'.$this->createUrl('training/admin') . '";'
			));
		?>
	</div>

<?php $this->endWidget(); ?>
	<?php $this->widget( 'ext.EChosen.EChosen' ); ?>
</div><!-- form -->
<?php /*
<script type="text/javascript">
	$(document).ready(function(){
		$('#client_select').change(function(){
			$.ajax({
				url: "<?php echo $this->createUrl('goal/byClient')?>/" + $(this).val(),
				context: $('#goal-select')
			}).done(function(data) {
				$('#goal-select_chzn').remove();
				var el = $(this);
				var newOptions = jQuery.parseJSON(data);
				el.empty();
				$.each(newOptions, function(key, value) {
					el.append($("<option></option>")
					   .attr("value", key).text(value));
				});
				el.removeClass('chzn-done');
				el.chosen([]);
			});
		});
	});
</script> */ ?>