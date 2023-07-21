<?php
$this->breadcrumbs=array(
	'Lockers'=>array('admin'),
	'Log'
);
$pageSize=Yii::app()->user->getState('pageSize',Yii::app()->params['defaultPageSize']);
?>

<h1>Lockers Log</h1>

<p>
You may optionally enter a comparison operator (<b>&lt;</b>, <b>&lt;=</b>, <b>&gt;</b>, <b>&gt;=</b>, <b>&lt;&gt;</b>
or <b>=</b>) at the beginning of each of your search values to specify how the comparison should be done.
</p>
<?php $this->widget('zii.widgets.grid.CGridView', array(
	'id'=>'lockerlog-grid',
	'dataProvider'=>$model->search(),
	'filter'=>$model,
	'rowCssClassExpression' => '"id_" . $data->getPrimaryKey() . " " . ($row %2 ? "even" : "odd")',
	'summaryText' => 'Displaying {start}-{end} of {count} result(s). Show items per page: ' . CHtml::dropDownList('pageSize', $pageSize, array(10 => 10, 20 => 20, 50 => 50, 100 => 100), array(
		'onchange' => "$.fn.yiiGridView.update('locker-grid',{ data:{pageSize: $(this).val() }})",
	)),
	'columns'=>array(
		array(
			'name' => 'locker_search',
			'value' => '$data->locker ? $data->locker->getModelDisplay() : ""'
		),
		array(
			'name' => 'client_search',
			'value' => '$data->client ? $data->client->getModelDisplay() : ""'
		),
		'action',
		'date'
	),
)); ?>