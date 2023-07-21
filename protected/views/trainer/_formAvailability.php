<div class="form">
	<?php
	$form = $this->beginWidget('CActiveForm', array(
		'id'					 => 'trainerav-form',
		'enableAjaxValidation'	 => false,
		'action'			 => $model->isNewRecord ? $this->createUrl('trainer/createAvaliability') : $this->createUrl('trainer/updateAvaliability', array('id'			 => $model->id)),
		'htmlOptions'	 => array('enctype' => 'multipart/form-data'),
			)
	);
	?>

	<p class="note">Fields with <span class="required">*</span> are required.</p>
	
	<?php if ($model->trainer_id): ?>
		<?php echo $form->errorSummary($model); ?>
		<?php echo $form->hiddenField($model, 'trainer_id', array('size' => 60)); ?>
	<?php else: ?>
		<?php echo $form->labelEx($model, 'trainer_id'); ?>
		<?php echo CHtml::activeDropDownList($model, 'trainer_id', Trainer::getDropdownList(), array('style' => 'width:260px;')) ?>
		<?php echo $form->error($model, 'trainer_id'); ?>
	<?php endif; ?>

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
		<?php echo $form->labelEx($model, 'date'); ?>
		<?php
		$this->widget('zii.widgets.jui.CJuiDatePicker', array(
			'attribute'	 => 'date',
			'model'		 => $model,
			'options'	 => array(
				'showAnim'	 => 'fold',
				'dateFormat' => 'dd-mm-yy'
			),
		));
		?>
		<?php echo $form->error($model, 'date'); ?>
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
		<?php echo $form->error($model, 'from'); ?>
	</div>

	<div class="row buttons">
		<?php echo CHtml::submitButton($model->isNewRecord ? 'Create' : 'Save', array('id' => 'submitAvailability')); ?>
		<?php if (!$model->isNewRecord) {
			echo CHtml::htmlButton('Delete', array(
				'onclick' => "if (confirm('Do you really want to delete availability data?')) {
					$.post('" . $this->createUrl('trainer/deleteAvaliability', array('id' => $model->id, 'ajax' => 1)). "', {
						success: function() {
							$('#avalability').dialog('close');
							$('#calendar').fullCalendar( 'refetchEvents' );
						}
					});
				}"
			));
		} ?>
	</div>

	<?php $this->endWidget(); ?>
</div><!-- form -->
<script type="text/javascript">
	$('#trainerav-form input').blur(function() {
		if (!$(this).val()) {
			$(this).addClass('error');
			$('#submitAvailability').attr("disabled", "disabled");;
		} else {
			$(this).removeClass('error');
			$('#submitAvailability').removeAttr("disabled");
		}
	});
	$('#TrainerAvailability_training_type_id').change(function(){
		var el = $(this);
		if (el.val() != 1) {
			$('.toField').hide();
		} else {
			$('.toField').show();
		}
	});
</script>